class Freddy
  module Consumers
    class RespondToConsumer
      def self.consume(*attrs, &block)
        new(*attrs).consume(&block)
      end

      def initialize(thread_pool:, destination:, channel:, handler_adapter_factory:)
        @consume_thread_pool = thread_pool
        @destination = destination
        @channel = channel
        @handler_adapter_factory = handler_adapter_factory
      end

      def consume(&block)
        consumer = consume_from_destination do |delivery|
          adapter = @handler_adapter_factory.for(delivery)

          msg_handler = MessageHandler.new(adapter, delivery)
          block.call(delivery.payload, msg_handler)
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def consume_from_destination(&block)
        @channel.queue(@destination).subscribe(manual_ack: true) do |delivery|
          process_message(delivery, &block)
        end
      end

      def process_message(delivery, &block)
        @consume_thread_pool.process do
          begin
            Freddy.trace = delivery.build_trace("freddy:respond:#{@destination}",
              tags: {queue: @destination}
            )
            Freddy.trace.log(
              event: 'Received message through respond_to',
              queue: @destination,
              payload: delivery.payload,
              correlation_id: delivery.correlation_id
            )

            block.call(delivery)
          ensure
            @channel.acknowledge(delivery.tag, false)
            Freddy.trace.finish
            Freddy.trace = nil
          end
        end
      end
    end
  end
end
