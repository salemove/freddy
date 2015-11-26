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

        def initialize(channel)
          @channel = channel
        end

        def_delegators :@channel, :topic, :default_exchange, :consumers

        def queue(*args)
          Queue.new(@channel.queue(*args))
        end

        def on_return(&block)
          default_exchange.on_return do |return_info, properties, content|
            block.call(return_info[:reply_code], properties[:correlation_id])
          end
        end
      end

      class Queue
        def initialize(queue)
          @queue = queue
        end

        def subscribe(&block)
          @queue.subscribe do |info, properties, payload|
            block.call(payload, Delivery.new(properties, info.routing_key))
          end
        end

        def bind(*args)
          @queue.bind(*args)
          self
        end

        def name
          @queue.name
        end
      end
    end
  end
end
