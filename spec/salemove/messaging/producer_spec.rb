require 'messaging_spec_helper'

module Salemove
  module Messaging
    describe Producer do

      default_let

      it 'accepts additional parameters for publishing' do 
        producer.produce destination, payload, content_type: 'application/html'
      end

      describe 'with messages that need to be acknowledged' do 
        it 'raises error if no handler is provided' do
          expect { producer.produce_with_ack destination, payload }.to raise_error Producer::EmptyAckHandler
        end
      end

    end
  end
end