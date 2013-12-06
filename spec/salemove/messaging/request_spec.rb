require 'messaging_spec_helper'
require 'salemove/messaging/request'

module Salemove
  module Messaging
    describe Request do

      default_let
      let(:req) { Request.new }
      let(:destination2) { random_destination }
      let(:test_response) { {custom: 'response'}}

      def default_request(&block)
        req.request destination, payload do |response|
          @received_response = response
          block.call response if block
        end
        default_sleep
      end

      def default_respond_to(&block)
        @responder = req.respond_to destination do |request_payload|
          @message_received = true
          @received_payload = request_payload
          block.call request_payload if block
        end
      end

      it 'raises empty request exception when requesting without callback' do 
        expect { req.request destination, payload }.to raise_error Request::EmptyRequest
      end

      it 'raises empty responder exception when responding without callback' do 
        expect {@responder = req.respond_to destination }.to raise_error Request::EmptyResponder
      end

      it 'sends the request to responder' do 
        default_respond_to
        default_request
        expect(@message_received).to be_true
      end

      it 'sends the payload in request to the responder' do 
        default_respond_to do 

        end
        payload = {a: 'ari'}
        req.request destination, payload do
          #NOP
        end
        default_sleep
        default_sleep

        expect(@received_payload).to eq Messaging.symbolize_keys(payload)
      end

      it 'sends the response to requester' do 
        @responder = req.respond_to destination do |request_payload|
          test_response
        end
        default_request
        expect(@received_response).to eq(Messaging.symbolize_keys(test_response))
      end

      it 'responds to the correct requester' do
        @responder = req.respond_to destination do 
          test_response
        end

        req.request destination, payload do 
          @dest_response_received = true
        end

        req.request destination2, payload do 
          @dest2_response_received = true
        end
        default_sleep

        expect(@dest_response_received).to be_true
        expect(@dest2_response_received).to be_nil
      end

      it 'times out when no response comes' do 
        req.request destination, payload, 0.2 do |response|
          @error = response[:error]
        end
        sleep 0.35
        expect(@error).not_to be_nil
      end

      describe 'when responding with ack' do 
        it 'allows the message to be acknowledged' do 
          expect_any_instance_of(MessageHandler).to receive(:ack).exactly(:once).and_call_original
          req.respond_to destination do |payload, msg_handler|
            msg_handler.ack
          end
          default_produce_with_ack
          expect(@ack_error).to be_nil
        end

        it 'allows the message to be nacked' do 
          expect_any_instance_of(MessageHandler).to receive(:nack).exactly(:once).and_call_original
          req.respond_to destination do |payload, msg_handler|
            msg_handler.nack "this payload is very, very bad"
          end

          default_produce_with_ack
          expect(@ack_error).not_to be_nil
        end

        it "reports error if message wasn't acknowledged" do 
          req.respond_to destination do |payload, msg_handler|
            #NOP
          end
          default_produce_with_ack
          expect(@ack_error).not_to be_nil
        end

      end

    end
  end
end