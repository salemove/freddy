module Salemove
  module Messaging
    class MessageHandler

      def initialize(channel, delivery_info, properties)
        @channel = channel
        @delivery_info = delivery_info
        @properties = properties
      end

      def cancel_consumer
        delivery_info.consumer.cancel
      end

      def nack(requeue)
        # @channel.nack(delivery_info.delivery_tag, false, requeue)
      end

      def ack
        # @channel.ack(delivery_info.delivery_tag)
      end

      def properties
        @properties
      end

    end
  end
end