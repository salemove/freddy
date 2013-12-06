module Salemove
  module Messaging
    class Messenger

      def initialize(use_unique_channel = false, logger = Messaging.logger)
        initalize_channel(use_unique_channel)
        @logger = logger
        @consumer, @producer = Consumer.new(@channel, @logger), Producer.new(@channel, @logger)
      end

      def consume(destination, &block)
        @consumer.consume destination, &block
      end

      def produce(destination, payload, properties = {})
        @producer.produce destination, payload, properties
      end

      private 

      def initalize_channel(use_unique_channel)
        if use_unique_channel
          @channel = Messaging.new_channel
        else
          @channel = Messaging.channel
        end
      end


    end
  end
end