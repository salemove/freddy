require 'spec_helper'

describe 'Logging' do
  let(:freddy1) { Freddy.build(logger1, config) }
  let(:freddy2) { Freddy.build(logger2, config) }

  let(:logger1) { spy('logger1') }
  let(:logger2) { spy('logger2') }

  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  after { [freddy1, freddy2].each(&:close) }

  before do
    freddy1.respond_to destination do |payload, msg_handler|
      msg_handler.success
    end

    freddy2.deliver_with_response(destination, payload) { }
    default_sleep
  end

  it 'logs all consumed messages' do
    expect(logger1).to have_received(:info).with(/Listening for requests on \S+/)
    expect(logger1).to have_received(:debug).with(
      message: 'Received message',
      queue: destination,
      payload: payload,
      correlation_id: anything
    )
  end

  it 'logs all produced messages' do
    expect(logger2).to have_received(:debug).with(/Consuming messages on \S+/)
    expect(logger2).to have_received(:debug).with(
      message: 'Publishing request',
      queue: destination,
      payload: payload,
      response_queue: anything,
      correlation_id: anything
    )
  end
end
