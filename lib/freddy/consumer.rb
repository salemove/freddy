require_relative 'responder_handler'
require_relative 'message_handler'
require_relative 'delivery'
require_relative 'consumers/tap_into_consumer'

class Freddy
  class Consumer

    class EmptyConsumer < Exception
    end

    def initialize(channel, logger, consume_thread_pool)
      @channel, @logger = channel, logger
      @consume_thread_pool = consume_thread_pool
      @dedicated_thread_pool = Thread.pool(1) # used only internally
      @tap_into_consumer = Consumers::TapIntoConsumer.new(consume_thread_pool, channel)
    end

    def consume(destination, options = {}, &block)
      raise EmptyConsumer unless block
      consume_from_queue create_queue(destination), options, &block
    end

    def consume_from_queue(queue, options = {}, &block)
      consume_using_pool(queue, options, @consume_thread_pool, &block)
    end

    def dedicated_consume(queue, &block)
      consume_using_pool(queue, {}, @dedicated_thread_pool, &block)
    end

    def tap_into(pattern, &block)
      @logger.debug "Tapping into messages that match #{pattern}"
      @tap_into_consumer.consume(pattern, &block)
    end

    private

    def consume_using_pool(queue, options, pool, &block)
      consumer = queue.subscribe do |payload, delivery|
        pool.process do
          parsed_payload = Payload.parse(payload)
          log_receive_event(queue.name, parsed_payload, delivery.correlation_id)
          block.call parsed_payload, delivery
        end
      end
      @logger.debug "Consuming messages on #{queue.name}"
      ResponderHandler.new consumer, pool
    end

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
