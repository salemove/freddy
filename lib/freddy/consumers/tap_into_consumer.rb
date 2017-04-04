class Freddy
  module Consumers
    class TapIntoConsumer
      def self.consume(*attrs, &block)
        new(*attrs).consume(&block)
      end

      def initialize(thread_pool:, pattern:, channel:, options:)
        @consume_thread_pool = thread_pool
        @pattern = pattern
        @channel = channel
        @options = options
      end

      def consume(&block)
        queue = create_queue

        consumer = queue.subscribe(manual_ack: true) do |delivery|
          process_message(queue, delivery, &block)
        end

        ResponderHandler.new(consumer, @consume_thread_pool)
      end

      private

      def create_queue
        topic_exchange = @channel.topic(Freddy::FREDDY_TOPIC_EXCHANGE_NAME)
        group = @options.fetch(:group, nil)

        if group
          @channel
            .queue("groups.#{group}")
            .bind(topic_exchange, routing_key: @pattern)
        else
          @channel
            .queue('', exclusive: true)
            .bind(topic_exchange, routing_key: @pattern)
        end
      end

      def process_message(queue, delivery, &block)
        @consume_thread_pool.process do
          begin
            Freddy.trace = delivery.build_trace("freddy:observe:#{@pattern}",
              tags: {
                'message_bus.destination': @pattern,
                'component': 'freddy',
                'span.kind': 'consumer' # Message Bus
              },
              force_follows_from: true
            )
            Freddy.trace.log(
              event: 'Received message through tap_into',
              payload: delivery.payload,
              correlation_id: delivery.correlation_id
            )

            block.call delivery.payload, delivery.routing_key
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
