require 'spec_helper'
require 'logasm/tracer'

describe 'Logging with Logasm::Tracer' do
  let(:logger) { ArrayLogger.new }
  let(:tracer) { Logasm::Tracer.new(logger) }

  before { OpenTracing.global_tracer = tracer }
  after { OpenTracing.global_tracer = nil }

  context 'when receiving an untraced request' do
    let(:freddy) { Freddy.build(spy, config) }
    let(:destination) { random_destination }

    before do
      freddy.respond_to(destination) do |payload, msg_handler|
        msg_handler.success({})
      end
    end

    after { freddy.close }

    it 'generates a trace' do
      freddy.deliver_with_response(destination, {})

      expect(logger.calls.map(&:first)).to eq([
        # Initiator
        "Span [freddy:request:#{destination}] started",
        "Span [freddy:request:#{destination}] Publishing request",

        # Service
        "Span [freddy:respond:#{destination}] started",
        "Span [freddy:respond:#{destination}] Received message through respond_to",
        "Span [freddy:respond:#{destination}] Sending response",
        "Span [freddy:respond:#{destination}] finished",

        # Initiator
        "Span [freddy:request:#{destination}] finished"
      ])
    end
  end

  context 'when receiving a traced request' do
    let(:freddy) { Freddy.build(spy, config) }
    let(:freddy2) { Freddy.build(spy, config) }

    let(:destination) { random_destination }
    let(:destination2) { random_destination }

    before do
      freddy.respond_to(destination) do |payload, msg_handler|
        msg_handler.success({
          trace_initiator: {},
          current_receiver: freddy.deliver_with_response(destination2, {})
        })
      end

      freddy2.respond_to(destination2) do |payload, msg_handler|
        msg_handler.success({})
      end
    end

    after do
      freddy.close
      freddy2.close
    end

    it 'generates a trace' do
      freddy.deliver_with_response(destination, {})

      expect(logger.calls.map(&:first)).to eq([
        # Initiator
        "Span [freddy:request:#{destination}] started",
        "Span [freddy:request:#{destination}] Publishing request",

        # Service 1
        "Span [freddy:respond:#{destination}] started",
        "Span [freddy:respond:#{destination}] Received message through respond_to",
        "Span [freddy:request:#{destination2}] started",
        "Span [freddy:request:#{destination2}] Publishing request",

        # Service 2
        "Span [freddy:respond:#{destination2}] started",
        "Span [freddy:respond:#{destination2}] Received message through respond_to",
        "Span [freddy:respond:#{destination2}] Sending response",
        "Span [freddy:respond:#{destination2}] finished",

        # Service 1
        "Span [freddy:request:#{destination2}] finished",
        "Span [freddy:respond:#{destination}] Sending response",
        "Span [freddy:respond:#{destination}] finished",

        # Initiator
        "Span [freddy:request:#{destination}] finished"
      ])
    end
  end
end
