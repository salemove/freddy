require_relative 'responder_handler'
require_relative 'message_handler'
require_relative 'delivery'
require_relative 'consumers/tap_into_consumer'
require_relative 'consumers/respond_to_consumer'
require_relative 'consumers/response_consumer'

class Freddy
  class Consumer
    def initialize(channel, logger, consume_thread_pool, producer, connection)
      @channel, @logger = channel, logger
      @connection = connection
      @tap_into_consumer = Consumers::TapIntoConsumer.new(consume_thread_pool)
      @respond_to_consumer = Consumers::RespondToConsumer.new(consume_thread_pool, channel, producer, @logger)
      @response_consumer = Consumers::ResponseConsumer.new(@logger)
    end

    def response_consume(queue, &block)
      @logger.debug "Consuming messages on #{queue.name}"
      @response_consumer.consume(queue, &block)
    end

    def tap_into(pattern, &block)
      @logger.debug "Tapping into messages that match #{pattern}"
      @tap_into_consumer.consume(pattern, @connection.create_channel, &block)
    end

    def respond_to(destination, &block)
      @logger.info "Listening for requests on #{destination}"
      @respond_to_consumer.consume(destination, &block)
    end
  end
end
