class Freddy
  class ResponderHandler
    def initialize(consumer, consume_thread_pool)
      @consumer = consumer
      @consume_thread_pool = consume_thread_pool
    end

    # Shutdown responder
    #
    # Stop responding to messages immediately, Waits until all workers are
    # finished and then returns.
    #
    # @return [void]
    #
    # @example
    #   responder = freddy.respond_to 'Queue' do |msg, handler|
    #   end
    #   responder.shutdown
    def shutdown
      @consumer.cancel
      @consume_thread_pool.wait(:done)
    end
  end
end
