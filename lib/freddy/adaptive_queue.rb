class Freddy
  class AdaptiveQueue
    def initialize(queue)
      @queue = queue
    end

    def subscribe(&block)
      if hare?
        @queue.subscribe do |meta, payload|
          block.call(payload, Delivery.new(meta, meta.routing_key))
        end
      else
        @queue.subscribe do |info, properties, payload|
          block.call(payload, Delivery.new(properties, info.routing_key))
        end
      end
    end

    def bind(*args)
      @queue.bind(*args)
      self
    end

    def name
      @queue.name
    end

    private

    def hare?
      RUBY_PLATFORM == 'java'
    end
  end
end
