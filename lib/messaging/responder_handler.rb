module Messaging
  class ResponderHandler

    def initialize(consumer, channel)
      @consumer = consumer
      @channel = channel
    end

    def cancel
      @consumer.cancel
    end

    def queue
      @consumer.queue
    end

    def destroy_destination
      @consumer.queue.delete
    end

    def join
      @channel.work_pool.join
    end

  end
end
