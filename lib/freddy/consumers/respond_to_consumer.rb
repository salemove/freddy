class Freddy
  module Consumers
    class RespondToConsumer
      def initialize(consume_thread_pool, channel, producer, logger)
        @consume_thread_pool = consume_thread_pool
        @channel = channel
        @producer = producer
        @logger = logger
        @response_queue_lock = Mutex.new
      end

      def consume(destination, &block)
        ensure_response_queue_exists

        consumer = consume_from_destination(destination) do |payload, delivery|
          log_receive_event(destination, payload, delivery.correlation_id)

          handler_class = MessageHandlers.for_type(delivery.metadata.type)
          handler = handler_class.new(@producer, destination, @logger)

          msg_handler = MessageHandler.new(handler, delivery)
          handler.handle_message payload, msg_handler, &block
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def consume_from_destination(destination, &block)
        @channel.queue(destination).subscribe do |payload, delivery|
          process_message(payload, delivery, &block)
        end
      end

      def process_message(payload, delivery, &block)
        @consume_thread_pool.process do
          block.call Payload.parse(payload), delivery
        end
      end

      def log_receive_event(destination, payload, correlation_id)
        if defined?(Logasm) && @logger.is_a?(Logasm)
          @logger.debug "Received message", queue: destination, payload: payload, correlation_id: correlation_id
        else
          @logger.debug "Received message on #{destination} with payload #{payload} with correlation_id #{correlation_id}"
        end
      end

      def ensure_response_queue_exists
        return @response_queue if defined?(@response_queue)

        @response_queue_lock.synchronize do
          @response_queue = @channel.queue('', exclusive: true)
        end
      end
    end
  end
end
