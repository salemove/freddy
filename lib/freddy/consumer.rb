require_relative 'responder_handler'
require_relative 'message_handler'
require_relative 'request'
require_relative 'delivery'

class Freddy
  class Consumer

    class EmptyConsumer < Exception
    end

    def initialize(channel, logger, consume_thread_pool)
      @channel, @logger = channel, logger
      @topic_exchange = @channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
      @consume_thread_pool = consume_thread_pool
      @dedicated_thread_pool = Thread.pool(1) # used only internally
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
      queue = create_queue('', exclusive: true).bind(@topic_exchange, routing_key: pattern)
      consumer = queue.subscribe do |payload, delivery|
        @consume_thread_pool.process do
          block.call parse_payload(payload), delivery.routing_key
        end
      end
      @logger.debug "Tapping into messages that match #{pattern}"
      ResponderHandler.new consumer, @channel
    end

    private

    def consume_using_pool(queue, options, pool, &block)
      consumer = queue.subscribe options do |delivery_info, properties, payload|
        pool.process do
          parsed_payload = parse_payload(payload)
          log_receive_event(queue.name, parsed_payload, properties[:correlation_id])
          block.call parsed_payload, Delivery.new(delivery_info, properties)
        end
      end
      @logger.debug "Consuming messages on #{queue.name}"
      ResponderHandler.new consumer, @channel
    end

    def parse_payload(payload)
      if payload == 'null'
        {}
      else
        Symbolizer.symbolize(JSON(payload))
      end
    end

    def create_queue(destination, options={})
      AdaptiveQueue.new(@channel.queue(destination, options))
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
