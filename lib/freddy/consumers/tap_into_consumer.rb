# frozen_string_literal: true

class Freddy
  module Consumers
    class TapIntoConsumer
      def self.consume(**attrs, &)
        new(**attrs).consume(&)
      end

      def initialize(thread_pool:, patterns:, channel:, options:)
        @consume_thread_pool = thread_pool
        @patterns = patterns
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
        topic_exchange = @channel.topic(exchange_name)

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
        @consume_thread_pool.post do
          delivery.in_span do
            yield delivery.payload, delivery.routing_key, delivery.timestamp
            @channel.acknowledge(delivery.tag)
          end
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
        end
      end

      def group
        @options.fetch(:group, nil)
      end

      def durable?
        @options.fetch(:durable, true)
      end

      def on_exception
        @options.fetch(:on_exception, :ack)
      end

      def exchange_name
        @options.fetch(:exchange_name, Freddy::FREDDY_TOPIC_EXCHANGE_NAME)
      end
    end
  end
end
