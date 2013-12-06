module Salemove
  module Messaging
    class ResponderHandler

      def initialize(consumer)
        @consumer = consumer
      end

      def cancel
        @consumer.cancel
      end

      def queue
        @consumer.queue
      end

    end
  end
end