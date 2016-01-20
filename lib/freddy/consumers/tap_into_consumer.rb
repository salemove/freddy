class Freddy
  module Consumers
    class TapIntoConsumer
      def initialize(consume_thread_pool, logger)
        @logger = logger
        @consume_thread_pool = consume_thread_pool
      end

      def consume(pattern, channel, &block)
        queue = create_queue(pattern, channel)

        consumer = queue.subscribe do |delivery|
          process_message(queue, delivery, &block)
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def create_queue(pattern, channel)
        topic_exchange = channel.topic(Freddy::FREDDY_TOPIC_EXCHANGE_NAME)

        channel
          .queue('', exclusive: true)
          .bind(topic_exchange, routing_key: pattern)
      end

      def process_message(queue, delivery, &block)
        @consume_thread_pool.process do
          Consumers.log_receive_event(@logger, queue.name, delivery)
          block.call delivery.payload, delivery.routing_key
        end
      end
    end
  end
end
