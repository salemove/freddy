require 'messaging_spec_helper'

module Salemove
  module Messaging
    describe Consumer do

      default_let

      it 'consumes messages' do
        default_consume
      end

      it 'consumes messages from an existing queue' do 
        consumer_handler = default_consume
        consumer.consume_from_queue consumer_handler.queue do 
        end
      end 

      it 'raises exception when no consumer is provided' do 
        expect { consumer.consume destination }.to raise_error Consumer::EmptyConsumer
        expect { 
          consumer_handler = consumer.consume destination do 
          end 
          consumer.consume_from_queue consumer_handler.queue
        }.to raise_error Consumer::EmptyConsumer
      end

      it "doesn't call passed block without any messages" do
        default_consume
        expect(@message_received).not_to be true
      end

      describe 'when consuming with ack' do 
        it 'allows the message to be acknowledged' do 
          consumer.consume_with_ack destination do |payload, acknowledger|
            acknowledger.ack
          end
          default_produce_with_ack
        end

        it 'allows the message to be nacked' do 
          consumer.consume_with_ack destination do |payload, acknowledger|
            acknowledger.nack "this payload is very, very bad"
          end
          default_produce_with_ack
        end
      end
    end
  end
end
