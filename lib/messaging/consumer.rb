require_relative 'responder_handler'
require_relative 'message_handler'
require_relative 'request'

module Messaging
  class Consumer

    class EmptyConsumer < Exception
    end

    def initialize(channel = Freddy.channel, logger=Freddy.logger)
      @channel, @logger = channel, logger
      @topic_exchange = @channel.topic $FREDDY_TOPIC_EXCHANGE_NAME
    end

    def consume(destination, options = {}, &block)
      raise EmptyConsumer unless block
      consume_from_queue create_queue(destination), options, &block
    end

    def consume_from_queue(queue, options = {}, &block)
      consumer = queue.subscribe options do |delivery_info, properties, payload|
        @logger.debug "Received message on #{queue.name} with payload #{payload}"
        block.call (parse_payload payload), MessageHandler.new(delivery_info, properties)
      end
      @logger.debug "Consuming messages on #{queue.name}"
      ResponderHandler.new consumer, @channel
    end

    def tap_into(pattern, options, &block)
      queue = @channel.queue("", exclusive: true).bind(@topic_exchange, routing_key: pattern)
      consumer = queue.subscribe options do |delivery_info, properties, payload|
        block.call (parse_payload payload), delivery_info.routing_key
      end
      @logger.debug "Tapping into messages that match #{pattern}"
      ResponderHandler.new consumer, @channel
    end

    private

    def parse_payload(payload)
      if payload == 'null'
        {}
      else
        Symbolizer.symbolize(JSON(payload))
      end
    end

    def create_queue(destination)
      @channel.queue(destination)
    end

  end
end