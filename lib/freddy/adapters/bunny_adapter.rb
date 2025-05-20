# frozen_string_literal: true

require 'bunny'
require 'forwardable'

class Freddy
  module Adapters
    class BunnyAdapter
      DEFAULT_OPTIONS = {
        connection_timeout: 5,
        read_timeout: 5,
        write_timeout: 5
      }.freeze

      def self.connect(config)
        bunny = Bunny.new(DEFAULT_OPTIONS.merge(config))
        bunny.start
        new(bunny)
      end

      def initialize(bunny)
        @bunny = bunny
      end

      def create_channel(prefetch: nil)
        bunny_channel = @bunny.create_channel
        bunny_channel.prefetch(prefetch) if prefetch
        Channel.new(bunny_channel)
      end

      def close
        @bunny.close
      end

      class Channel
        extend Forwardable

        NO_ROUTE = 312

        def initialize(channel)
          @channel = channel
        end

        def_delegators :@channel, :topic, :default_exchange, :consumers, :acknowledge, :reject

        def queue(*)
          Queue.new(@channel.queue(*))
        end

        def on_no_route
          default_exchange.on_return do |return_info, properties, _content|
            yield(properties[:correlation_id]) if return_info[:reply_code] == NO_ROUTE
          end
        end
      end

      class Queue
        def initialize(queue)
          @queue = queue
        end

        def bind(*)
          @queue.bind(*)
          self
        end

        def name
          @queue.name
        end

        def message_count
          @queue.message_count
        end

        def subscribe(manual_ack: false)
          @queue.subscribe(manual_ack: manual_ack) do |info, properties, payload|
            parsed_payload = Payload.parse(payload, properties[:content_encoding])
            delivery = Delivery.new(
              parsed_payload, properties, info.routing_key, info.delivery_tag, info.exchange
            )
            yield(delivery)
          end
        end
      end
    end
  end
end
