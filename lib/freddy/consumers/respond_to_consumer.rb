class Freddy
  module Consumers
    class RespondToConsumer
      def initialize(consume_thread_pool, logger)
        @consume_thread_pool = consume_thread_pool
        @logger = logger
      end

      def consume(destination, channel, &block)
        producer = Producers::SendAndForgetProducer.new(channel, @logger)

        consumer = consume_from_destination(destination, channel) do |delivery|
          log_receive_event(destination, delivery)

          handler_class = MessageHandlers.for_type(delivery.type)
          handler = handler_class.new(producer, destination, @logger)

          msg_handler = MessageHandler.new(handler, delivery)
          handler.handle_message delivery.payload, msg_handler, &block
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def consume_from_destination(destination, channel, &block)
        channel.queue(destination).subscribe do |delivery|
          process_message(delivery, &block)
        end
      end

      def process_message(delivery, &block)
        @consume_thread_pool.process do
          block.call(delivery)
        end
      end

      def log_receive_event(destination, delivery)
        if defined?(Logasm) && @logger.is_a?(Logasm)
          @logger.debug "Received message", queue: destination, payload: delivery.payload, correlation_id: delivery.correlation_id
        else
          @logger.debug "Received message on #{destination} with payload #{delivery.payload} with correlation_id #{delivery.correlation_id}"
        end
      end
    end
  end
end
