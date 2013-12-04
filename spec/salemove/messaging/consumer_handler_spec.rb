require 'messaging_spec_helper'
require 'salemove/messaging/consumer_handler'

module Salemove
  module Messaging
    describe ConsumerHandler do

      default_let

      it 'can cancel listening for messages' do 
        consumer_handler = default_consume
        default_produce
        consumer_handler.cancel
        default_produce

        expect(@messages_count).to eq 1
      end

    end
  end
end
