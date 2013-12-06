require 'messaging_spec_helper'

module Salemove
  module Messaging
    describe Consumer do

      default_let

      it 'raises exception when no consumer is provided' do 
        expect { consumer.consume destination }.to raise_error Consumer::EmptyConsumer
      end

      it "doesn't call passed block without any messages" do
        default_consume
        expect(@message_received).not_to be true
        default_produce
      end

      describe 'when consuming with ack' do 
        it 'allows the message to be acknowledged' do 
          expect_any_instance_of(MessageHandler).to receive(:ack).exactly(:once).and_call_original
          consumer.consume destination do |payload, msg_handler|
            msg_handler.ack
          end
          default_produce_with_ack
          expect(@ack_error).to be_nil
        end

        it 'allows the message to be nacked' do 
          expect_any_instance_of(MessageHandler).to receive(:nack).exactly(:once).and_call_original
          consumer.consume destination do |payload, msg_handler|
            msg_handler.nack "this payload is very, very bad"
          end
          default_produce_with_ack
          expect(@ack_error).not_to be_nil
        end

        it "reports error if message wasn't acknowledged" do 
          consumer.consume destination do |payload, msg_handler|
            #NOP
          end
          default_produce_with_ack
          expect(@ack_error).not_to be_nil
        end

      end
    end
  end
end
