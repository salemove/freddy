require 'messaging_spec_helper'

describe 'Logging' do
  default_let
  let(:freddy1) { Freddy.new(logger1) }
  let(:freddy2) { Freddy.new(logger2) }

  let(:logger1) { spy('logger') }
  let(:logger2) { spy('logger') }

  before do
    freddy1.use_distinct_connection
    freddy2.use_distinct_connection
  end

  before do
    freddy1.respond_to destination do |payload, msg_handler|
      msg_handler.ack
    end

    freddy2.deliver_with_ack(destination, payload) { }
    default_sleep
  end

  it 'logs all consumed messages' do
    expect(logger1).to have_received(:debug).with(/Listening for requests on \w+/)
    expect(logger1).to have_received(:debug).with(/Consuming messages on \w+/)
    expect(logger1).to have_received(:debug).with(/Received message on \w+ with payload {"pay":"load"}/)
  end

  it 'logs all produced messages' do
    expect(logger2).to have_received(:debug).with(/Producing message {:pay=>"load"} to \w+/)
  end
end
