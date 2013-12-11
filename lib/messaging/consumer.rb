require 'messaging/responder_handler'
require 'messaging/message_handler'
require 'messaging/request'

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

    def tap(destination, options, &block) 
      queue = @channel.queue("", exclusive: true).bind(@topic_exchange, routing_key: destination)
      consumer = queue.subscribe options do |delivery_info, metadata, payload|
        block.call (parse_payload payload)
      end
      @logger.debug "Tapping into messages that match #{destination}"
      ResponderHandler.new consumer, @channel
    end

    private

    def parse_payload(payload)
      if payload == 'null'
        {}
      else
        Freddy.symbolize_keys(JSON(payload))
      end
    end

    def create_queue(destination)
      @channel.queue(destination)
    end

  end
end