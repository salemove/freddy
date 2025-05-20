# frozen_string_literal: true

class Freddy
  module Consumers
    class RespondToConsumer
      def self.consume(**attrs, &)
        new(**attrs).consume(&)
      end

      def initialize(thread_pool:, destination:, channel:, handler_adapter_factory:)
        @consume_thread_pool = thread_pool
        @destination = destination
        @channel = channel
        @handler_adapter_factory = handler_adapter_factory
      end

      def consume
        consumer = consume_from_destination do |delivery|
          adapter = @handler_adapter_factory.for(delivery)

          msg_handler = MessageHandler.new(adapter, delivery)
          yield(delivery.payload, msg_handler)
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def consume_from_destination(&block)
        @channel.queue(@destination).subscribe(manual_ack: true) do |delivery|
          process_message(delivery, &block)
        end
      end

      def process_message(delivery)
        @consume_thread_pool.post do
          delivery.in_span do
            yield(delivery)
          end
        ensure
          @channel.acknowledge(delivery.tag, false)
        end
      end
    end
  end
end
