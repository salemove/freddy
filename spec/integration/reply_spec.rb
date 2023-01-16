require 'spec_helper'

describe 'Reply' do
  let(:freddy) { Freddy.build(logger, **config) }

  let(:destination) { random_destination }
  let(:request_payload) { { req: 'load' } }
  let(:response_payload) { { res: 'load' } }

  after { freddy.close }

  context 'when a synchronized request' do
    before do
      freddy.respond_to(destination) do |_payload, msg_handler|
        msg_handler.success(response_payload)
      end
    end

    it 'sends reply' do
      response = freddy.deliver_with_response(destination, request_payload)
      expect(response).to eq(response_payload)
    end

    it 'does not send the reply to the topic queue' do
      freddy.tap_into 'amq.*' do |_payload|
        @message_received = true
      end

      freddy.deliver_with_response(destination, request_payload)
      default_sleep

      expect(@message_received).to be_falsy
    end
  end
end
