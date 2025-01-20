require 'spec_helper'

describe 'Tracing' do
  let(:exporter) { SPAN_EXPORTER }

  before do
    exporter.reset
  end

  context 'when receiving a traced request' do
    let(:freddy) { Freddy.build(logger, **config) }
    let(:freddy2) { Freddy.build(logger, **config) }

    let(:destination) { random_destination }
    let(:destination2) { random_destination }

    before do
      freddy.respond_to(destination) do |_payload, msg_handler|
        msg_handler.success(
          trace_initiator: current_span_attributes,
          current_receiver: freddy.deliver_with_response(destination2, {})
        )
      end

      freddy2.respond_to(destination2) do |_payload, msg_handler|
        msg_handler.success(current_span_attributes)
      end
    end

    after do
      freddy.close
      freddy2.close
    end

    it 'has trace_id from the trace initiator' do
      response = freddy.deliver_with_response(destination, {})
      trace_initiator = response.fetch(:trace_initiator)
      current_receiver = response.fetch(:current_receiver)
      expect(trace_initiator.fetch(:trace_id)).to eq(current_receiver.fetch(:trace_id))
    end

    it 'has parent_id' do
      response = freddy.deliver_with_response(destination, {})
      current_receiver = response.fetch(:current_receiver)
      expect(current_receiver.fetch(:parent_id)).not_to be_nil
    end

    it 'has generated span_id' do
      response = freddy.deliver_with_response(destination, {})
      trace_initiator = response.fetch(:trace_initiator)
      current_receiver = response.fetch(:current_receiver)
      expect(current_receiver.fetch(:span_id)).not_to be_nil
      expect(current_receiver.fetch(:span_id)).not_to eq(trace_initiator.fetch(:span_id))
    end

    it 'replaces generated queue names with (response queue)' do
      freddy.deliver_with_response(destination, {})
      names = exporter.finished_spans.map(&:name)

      expect(names.any? { |name| name.include?('amq.gen-') }).to be(false)
      expect(names.any? { |name| name.include?('(response queue)') }).to be(true)
    end
  end

  context 'when receiving a nested traced request' do
    let(:freddy) { Freddy.build(logger, **config) }
    let(:freddy2) { Freddy.build(logger, **config) }
    let(:freddy3) { Freddy.build(logger, **config) }

    let(:destination) { random_destination }
    let(:destination2) { random_destination }
    let(:destination3) { random_destination }

    before do
      freddy.respond_to(destination) do |_payload, msg_handler|
        msg_handler.success({
          trace_initiator: current_span_attributes
        }.merge(freddy.deliver_with_response(destination2, {})))
      end

      freddy2.respond_to(destination2) do |_payload, msg_handler|
        msg_handler.success(
          previous_receiver: current_span_attributes,
          current_receiver: freddy2.deliver_with_response(destination3, {})
        )
      end

      freddy3.respond_to(destination3) do |_payload, msg_handler|
        msg_handler.success(current_span_attributes)
      end
    end

    after do
      freddy.close
      freddy2.close
      freddy3.close
    end

    it 'has trace_id from the trace initiator' do
      response = freddy.deliver_with_response(destination, {})
      trace_initiator = response.fetch(:trace_initiator)
      current_receiver = response.fetch(:current_receiver)
      expect(trace_initiator.fetch(:trace_id)).to eq(current_receiver.fetch(:trace_id))
    end

    it 'has parent_id' do
      response = freddy.deliver_with_response(destination, {})
      current_receiver = response.fetch(:current_receiver)
      expect(current_receiver.fetch(:parent_id)).not_to be_nil
    end

    it 'has generated span_id' do
      response = freddy.deliver_with_response(destination, {})
      previous_receiver = response.fetch(:previous_receiver)
      current_receiver = response.fetch(:current_receiver)
      expect(current_receiver.fetch(:span_id)).not_to be_nil
      expect(current_receiver.fetch(:span_id)).not_to eq(previous_receiver.fetch(:span_id))
    end
  end

  context 'when receiving a broadcast' do
    let(:freddy) { Freddy.build(logger, **config) }
    let(:destination) { random_destination }

    before do
      freddy.tap_into(destination) do
        @deliver_span = current_span_attributes
      end
    end

    after do
      freddy.close
    end

    it 'continues the existing trace' do
      Freddy.tracer.in_span('test') do
        freddy.deliver(destination, {})
      end
      wait_for { @deliver_span }

      expect(exporter.finished_spans.map(&:name))
        .to match([
                    /\.\w+ send/,
                    'test',
                    /freddy-topic\.\w+ process/
                  ])

      expect(exporter.finished_spans.map(&:trace_id).uniq.count).to eq(1)
    end
  end

  def current_span_attributes
    {
      trace_id: current_span.context.trace_id,
      parent_id: current_span.parent_span_id,
      span_id: current_span.context.span_id,
      links: current_span.links || []
    }
  end

  def current_span
    OpenTelemetry::Trace.current_span
  end
end
