require 'bunny'

class Freddy
  module Adapters
    class BunnyAdapter
      def self.connect(config)
        bunny = Bunny.new(config)
        bunny.start
        new(bunny)
      end

      def initialize(bunny)
        @bunny = bunny
      end

      def create_channel
        Channel.new(@bunny.create_channel)
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

        def_delegators :@channel, :topic, :default_exchange, :consumers

        def queue(*args)
          Queue.new(@channel.queue(*args))
        end

        def on_no_route(&block)
          default_exchange.on_return do |return_info, properties, content|
            if return_info[:reply_code] == NO_ROUTE
              block.call(properties[:correlation_id])
            end
          end
        end
      end

      class Queue < Shared::Queue
        def subscribe(&block)
          @queue.subscribe do |info, properties, payload|
            parsed_payload = Payload.parse(payload)
            block.call(Delivery.new(parsed_payload, properties, info.routing_key))
          end
        end
      end
    end
  end
end
