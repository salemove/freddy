class Freddy
  module Consumers
    class ResponseConsumer
      def initialize(logger)
        @logger = logger
        @dedicated_thread_pool = Thread.pool(1)
      end

      def consume(queue, &block)
        consumer = consume_from_queue(queue) do |payload, delivery|
          log_receive_event(queue.name, payload, delivery.correlation_id)
          block.call(payload, delivery)
        end
        ResponderHandler.new(consumer, @dedicated_thread_pool)
      end

      private

      def consume_from_queue(queue, &block)
        queue.subscribe do |payload, delivery|
          process_message(payload, delivery, &block)
        end
      end

      def process_message(payload, delivery, &block)
        @dedicated_thread_pool.process do
          block.call Payload.parse(payload), delivery
        end
      end

      def log_receive_event(queue_name, payload, correlation_id)
        if defined?(Logasm) && @logger.is_a?(Logasm)
          @logger.debug "Received message", queue: queue_name, payload: payload, correlation_id: correlation_id
        else
          @logger.debug "Received message on #{queue_name} with payload #{payload} with correlation_id #{correlation_id}"
        end
      end
    end
  end
end
