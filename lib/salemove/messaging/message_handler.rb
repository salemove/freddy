module Salemove
  module Messaging
    class MessageHandler
      attr_reader :properties, :response
      @acked = false

      def initialize(delivery_info, properties)
        @delivery_info = delivery_info
        @properties = properties
      end

      def nack(error = "Couldn't process message")
        @acked = false
        @error = error
        @response = { error: error }
      end

      def ack(response=nil)
        @acked = true
        @error = nil
        @response = response
      end

      def error
        return @error if @error and !@acked
        "Responder didn't manually acknowledge message" if !@acked
      end
    end
  end
end