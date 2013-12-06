require 'messaging_spec_helper'

module Salemove
  module Messaging
    describe MessageHandler do

      default_let

      it 'cancels listening' do 
        consumer_handler = default_consume 
        default_produce
        consumer_handler.cancel
        default_produce #this will not be received 
        expect(@messages_count).to eq 1
      end

      it 'has properties about message' do 
        properties = nil
        default_consume do |payload, msg_handler|
          properties = msg_handler.properties
        end
        default_produce
        expect(properties).not_to be_nil
      end

    end
  end
end
