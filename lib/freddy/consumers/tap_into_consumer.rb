require 'thread'

class Freddy
  module Consumers
    class TapIntoConsumer
      def initialize(consume_thread_pool, channel)
        @consume_thread_pool = consume_thread_pool
        @channel = channel
        @topic_exchange = @channel.topic(Freddy::FREDDY_TOPIC_EXCHANGE_NAME)
        @mutex = Mutex.new
      end

      def consume(pattern, &block)
        consumer = @mutex.synchronize do
          create_consumer(pattern, &block)
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private


      def create_consumer(pattern, &block)
        create_queue(pattern).subscribe do |delivery|
          process_message(delivery, &block)
        end
      end

      def create_queue(pattern)
        @channel
          .queue('', exclusive: true)
          .bind(@topic_exchange, routing_key: pattern)
      end

      def process_message(delivery, &block)
        @consume_thread_pool.process do
          block.call delivery.payload, delivery.routing_key
        end
      end
    end
  end
end
