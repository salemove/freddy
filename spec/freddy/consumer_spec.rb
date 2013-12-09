require 'messaging_spec_helper'

module Messaging
  describe Consumer do

    default_let

    it 'raises exception when no consumer is provided' do 
      expect { consumer.consume destination }.to raise_error Consumer::EmptyConsumer
    end

    it "doesn't call passed block without any messages" do
      consumer.consume destination do 
        @message_received = true
      end
      expect(@message_received).not_to be true
      default_deliver
    end

  end
end
