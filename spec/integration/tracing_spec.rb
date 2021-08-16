require 'spec_helper'
require 'opentracing_test_tracer'

describe 'Tracing' do
  let(:tracer) { OpenTracingTestTracer.build(logger: logger) }
  let(:logger) { spy }

  before { OpenTracing.global_tracer = tracer }

  after { OpenTracing.global_tracer = nil }

  context 'when receiving a traced request' do
    let(:freddy) { Freddy.build(logger, config) }
    let(:freddy2) { Freddy.build(logger, config) }

    let(:destination) { random_destination }
    let(:destination2) { random_destination }

    before do
      freddy.respond_to(destination) do |_payload, msg_handler|
        msg_handler.success(
          trace_initiator: {
            trace_id: active_span.context.trace_id,
            parent_id: active_span.context.parent_id,
            span_id: active_span.context.span_id
          },
          current_receiver: freddy.deliver_with_response(destination2, {})
        )
      end

      freddy2.respond_to(destination2) do |_payload, msg_handler|
        msg_handler.success(
          trace_id: active_span.context.trace_id,
          parent_id: active_span.context.parent_id,
          span_id: active_span.context.span_id
        )
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
  end

  context 'when receiving a nested traced request' do
    let(:freddy) { Freddy.build(logger, config) }
    let(:freddy2) { Freddy.build(logger, config) }
    let(:freddy3) { Freddy.build(logger, config) }

    let(:destination) { random_destination }
    let(:destination2) { random_destination }
    let(:destination3) { random_destination }

    before do
      freddy.respond_to(destination) do |_payload, msg_handler|
        msg_handler.success({
          trace_initiator: {
            trace_id: active_span.context.trace_id,
            parent_id: active_span.context.parent_id,
            span_id: active_span.context.span_id
          }
        }.merge(freddy.deliver_with_response(destination2, {})))
      end

      freddy2.respond_to(destination2) do |_payload, msg_handler|
        msg_handler.success(
          previous_receiver: {
            trace_id: active_span.context.trace_id,
            parent_id: active_span.context.parent_id,
            span_id: active_span.context.span_id
          },
          current_receiver: freddy2.deliver_with_response(destination3, {})
        )
      end

      freddy3.respond_to(destination3) do |_payload, msg_handler|
        msg_handler.success(
          trace_id: active_span.context.trace_id,
          parent_id: active_span.context.parent_id,
          span_id: active_span.context.span_id
        )
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

  def active_span
    OpenTracing.active_span
  end
end
