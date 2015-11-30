class Freddy
  module Consumers
    class ResponseConsumer
      def initialize(logger)
        @logger = logger
        @dedicated_thread_pool = Thread.pool(1)
      end

      def consume(queue, &block)
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

      def log_receive_event(queue_name, delivery)
        if defined?(Logasm) && @logger.is_a?(Logasm)
          @logger.debug "Received message", queue: queue_name, payload: delivery.payload, correlation_id: delivery.correlation_id
        else
          @logger.debug "Received message on #{queue_name} with payload #{delivery.payload} with correlation_id #{delivery.correlation_id}"
        end
      end
    end
  end
end
