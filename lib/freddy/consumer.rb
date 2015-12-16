class Freddy
  class Consumer
    def initialize(logger, consume_thread_pool, connection)
      @logger = logger
      @connection = connection
      @tap_into_consumer = Consumers::TapIntoConsumer.new(consume_thread_pool)
      @respond_to_consumer = Consumers::RespondToConsumer.new(consume_thread_pool, @logger)
    end

    def tap_into(pattern, &block)
      @logger.debug "Tapping into messages that match #{pattern}"
      @tap_into_consumer.consume(pattern, @connection.create_channel, &block)
    end

    def respond_to(destination, &block)
      @logger.info "Listening for requests on #{destination}"
      @respond_to_consumer.consume(destination, @connection.create_channel, &block)
    end
  end
end
