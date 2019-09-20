# frozen_string_literal: true

class Freddy
  module Consumers
    class TapIntoConsumer
      def self.consume(*attrs, &block)
        new(*attrs).consume(&block)
      end

      def initialize(thread_pool:, patterns:, channel:, options:)
        @consume_thread_pool = thread_pool
        @patterns = patterns
        @channel = channel
        @options = options

        raise 'Do not use durable queues without specifying a group' if durable? && !group
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

        queue =
          if group
            @channel.queue("groups.#{group}", durable: durable?)
          else
            @channel.queue('', exclusive: true)
          end

        @patterns.each do |pattern|
          queue.bind(topic_exchange, routing_key: pattern)
        end

        queue
      end

      def process_message(_queue, delivery)
        @consume_thread_pool.process do
          begin
            scope = delivery.build_trace("freddy:observe:#{@pattern}",
                                         tags: {
                                           'message_bus.destination' => @pattern,
                                           'message_bus.correlation_id' => delivery.correlation_id,
                                           'component' => 'freddy',
                                           'span.kind' => 'consumer' # Message Bus
                                         },
                                         force_follows_from: true)

            yield delivery.payload, delivery.routing_key

            @channel.acknowledge(delivery.tag)
          rescue StandardError
            case on_exception
            when :reject
              @channel.reject(delivery.tag)
            when :requeue
              @channel.reject(delivery.tag, true)
            else
              @channel.acknowledge(delivery.tag)
            end

            raise
          ensure
            scope.close
          end
        end
      end

      def group
        @options.fetch(:group, nil)
      end

      def durable?
        @options.fetch(:durable, false)
      end

      def on_exception
        @options.fetch(:on_exception, :ack)
      end
    end
  end
end
