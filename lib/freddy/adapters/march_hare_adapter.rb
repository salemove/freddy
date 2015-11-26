require 'march_hare'

class Freddy
  module Adapters
    class MarchHareAdapter
      def self.connect(config)
        hare = MarchHare.connect(config)
        new(hare)
      end

      def initialize(hare)
        @hare = hare
      end

      def create_channel
        Channel.new(@hare.create_channel)
      end

      def close
        @hare.close
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
          @channel.on_return do |reply_code, _, exchange_name, _, properties|
            if exchange_name != Freddy::FREDDY_TOPIC_EXCHANGE_NAME
              block.call(reply_code, properties.correlation_id)
            end
          end
        end
      end

      class Queue
        def initialize(queue)
          @queue = queue
        end

        def subscribe(&block)
          @queue.subscribe do |meta, payload|
            block.call(payload, Delivery.new(meta, meta.routing_key))
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
