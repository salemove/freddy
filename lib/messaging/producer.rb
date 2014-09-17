require_relative 'request'
require 'json'

module Messaging
  class Producer

    class EmptyAckHandler < Exception
    end

    def initialize(channel, logger)
      @channel, @logger = channel, logger
      @exchange = @channel.default_exchange
      @topic_exchange = @channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
    end

    def produce(destination, payload, properties={})
      @logger.debug "Producing message #{payload.inspect} to #{destination}"
      @topic_exchange.publish payload.to_json, properties.merge(routing_key: destination, content_type: 'application/json')
      @exchange.publish payload.to_json, properties.merge(routing_key: destination, content_type: 'application/json')
    end

    def produce_with_ack(destination, payload, timeout_seconds = 3, properties={}, &block)
      raise EmptyAckHandler unless block
      req = Request.new(@channel, @logger)
      producer = req.async_request destination, payload, timeout_seconds, properties.merge(mandatory: true, headers: {message_with_ack: true}) do |payload|
        block.call payload[:error]
      end

      producer.on_return do
        block.call({error: "No consumers for destination #{destination}"})
      end
    end
  end
end
