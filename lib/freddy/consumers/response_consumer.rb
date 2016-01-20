require_relative 'consumer'

class Freddy
  module Consumers
    class ResponseConsumer < Consumer
      def initialize(logger)
        @logger = logger
        @dedicated_thread_pool = Thread.pool(1)
      end

      def consume(queue, &block)
        @logger.debug "Consuming messages on #{queue.name}"
        consumer = queue.subscribe do |delivery|
          process_message(queue, delivery, &block)
        end
        ResponderHandler.new(consumer, @dedicated_thread_pool)
      end

      private

      def process_message(queue, delivery, &block)
        @dedicated_thread_pool.process do
          log_receive_event(queue.name, delivery)
          block.call(delivery)
        end
      end
    end
  end
end
