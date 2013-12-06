module Salemove
  module Messaging
    class MessageHandler
      attr_reader :acknowledger, :properties

      def initialize(channel, delivery_info, properties)
        @channel = channel
        @delivery_info = delivery_info
        @properties = properties
        @with_ack = @properties[:headers] && @properties[:headers]['message_with_ack'] || false
        @acknowledger = Acknowledger.new if @with_ack
      end

      def nack(error)
        @acknowledger.nack error if @acknowledger
      end

      def ack
        @acknowledger.ack if @acknowledger
      end

      private

      class Acknowledger 
        @acked = false

        def ack
          @acked = true
          @error = nil
        end

        def nack(error)
          @acked = false
          @error = error
        end

        def error
          if @error
            @error
          elsif !@acked
            "Consumer didn't manually acknowledge message"
          end
        end
      end

    end
  end
end