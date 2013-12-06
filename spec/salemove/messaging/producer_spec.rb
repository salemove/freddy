require 'messaging_spec_helper'

module Salemove
  module Messaging
    describe Producer do

      default_let

      it 'can produce messages' do
        default_produce
      end

      it 'accepts additional parameters for publishing' do 
        producer.produce destination, payload, content_type: 'application/html'
      end

      describe 'with messages that need to be acknowledged' do 
        it 'raises error if no handler is provided' do
          expect { producer.produce_with_ack destination, payload }.to raise_error Producer::EmptyAckHandler
        end

        it 'returns error if there are no consumers' do 
          default_produce_with_ack
          expect(@ack_error).not_to be_nil
        end

      end

    end
  end
end