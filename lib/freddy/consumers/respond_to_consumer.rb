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
            scope = delivery.build_trace("freddy:respond:#{@destination}",
              tags: {
                'peer.address' => "#{@destination}:#{delivery.payload[:type]}",
                'component' => 'freddy',
                'span.kind' => 'server', # RPC
                'message_bus.destination' => @destination,
                'message_bus.correlation_id' => delivery.correlation_id
              }
            )

            block.call(delivery)
          ensure
            @channel.acknowledge(delivery.tag, false)
            scope.close
          end
        end
      end
    end
  end
end
