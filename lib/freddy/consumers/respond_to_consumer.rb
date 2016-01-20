class Freddy
  module Consumers
    class RespondToConsumer
      def initialize(consume_thread_pool, logger)
        @consume_thread_pool = consume_thread_pool
        @logger = logger
      end

      def consume(destination, channel, handler_factory, &block)
        consumer = consume_from_destination(destination, channel) do |delivery|
          Consumers.log_receive_event(@logger, destination, delivery)

          handler = handler_factory.build(delivery.type, destination)

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
    end
  end
end
