class Freddy
  module Consumers
    class ResponseConsumer
      def initialize(logger)
        @logger = logger
      end

      def consume(channel, queue, &block)
        @logger.debug "Consuming messages on #{queue.name}"
        queue.subscribe do |delivery|
          process_message(channel, queue, delivery, &block)
        end
      end

      private

      def process_message(channel, queue, delivery, &block)
        Consumers.log_receive_event(@logger, queue.name, delivery)
        block.call(delivery)
      end
    end
  end
end
