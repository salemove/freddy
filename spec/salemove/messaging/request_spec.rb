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
        req.respond_to destination do |request_payload|
          @message_received = true
          @received_payload = request_payload
          block.call request_payload if block
        end
      end

      it 'raises empty request exception when requesting without callback' do 
        expect { req.request destination, payload }.to raise_error Request::EmptyRequest
      end

      it 'raises empty responder exception when responding without callback' do 
        expect {req.respond_to destination }.to raise_error Request::EmptyResponder
      end

      it 'sends the request to responder' do 
        default_respond_to
        default_request
        expect(@message_received).to be_true
      end

      it 'sends the payload in request to the responder' do 
        default_respond_to
        payload = {a: 'ari'}
        req.request destination, payload do
          #NOP
        end
        default_sleep

        expect(@received_payload).to eq Messaging.symbolize_keys(payload)
      end

      it 'sends the response to requester' do 
        default_respond_to do 
          test_response
        end
        default_request
        expect(@received_response).to eq(Messaging.symbolize_keys(test_response))
      end

      it 'responds to the correct requester' do
        req.respond_to destination do 
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

    end
  end
end