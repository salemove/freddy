require_relative 'responder_handler'
require_relative 'message_handler'
require_relative 'delivery'
require_relative 'consumers/tap_into_consumer'
require_relative 'consumers/respond_to_consumer'

class Freddy
  class Consumer
    class EmptyConsumer < Exception
    end

    def initialize(channel, logger, consume_thread_pool, producer)
      @channel, @logger = channel, logger
      @dedicated_thread_pool = Thread.pool(1) # used only internally
      @tap_into_consumer = Consumers::TapIntoConsumer.new(consume_thread_pool, channel)
      @respond_to_consumer = Consumers::RespondToConsumer.new(consume_thread_pool, channel, producer, @logger)
    end

    def dedicated_consume(queue, &block)
      consumer = queue.subscribe do |payload, delivery|
        @dedicated_thread_pool.process do
          parsed_payload = Payload.parse(payload)
          log_receive_event(queue.name, parsed_payload, delivery.correlation_id)
          block.call parsed_payload, delivery
        end
      end
      @logger.debug "Consuming messages on #{queue.name}"
      ResponderHandler.new consumer, @dedicated_thread_pool
    end

    def tap_into(pattern, &block)
      @logger.debug "Tapping into messages that match #{pattern}"
      @tap_into_consumer.consume(pattern, &block)
    end

    def respond_to(destination, &block)
      @logger.info "Listening for requests on #{destination}"
      @respond_to_consumer.consume(destination, &block)
    end

    private

    def create_queue(destination, options={})
      @channel.queue(destination, options)
    end

    def log_receive_event(queue_name, payload, correlation_id)
      if defined?(Logasm) && @logger.is_a?(Logasm)
        @logger.debug "Received message", queue: queue_name, payload: payload, correlation_id: correlation_id
      else
        @logger.debug "Received message on #{queue_name} with payload #{payload} with correlation_id #{correlation_id}"
      end
    end
  end
end
