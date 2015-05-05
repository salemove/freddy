require_relative 'request'
require 'json'

class Freddy
  class Producer
    CONTENT_TYPE = 'application/json'.freeze

    class EmptyAckHandler < Exception
    end

    def initialize(channel, logger)
      @channel, @logger = channel, logger
      @exchange = @channel.default_exchange
      @topic_exchange = @channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
    end

    def produce(destination, payload, properties={})
      @logger.debug "Producing message #{payload.inspect} to #{destination}"

      properties = properties.merge(routing_key: destination, content_type: CONTENT_TYPE)
      json_payload = payload.to_json

      @topic_exchange.publish json_payload, properties.dup
      @exchange.publish json_payload, properties.dup
    end

    def produce_with_ack(destination, payload, options, &block)
      raise EmptyAckHandler unless block
      req = Request.new(@channel, @logger)
      producer = req.async_request destination, payload, options.merge(mandatory: true, headers: {message_with_ack: true}) do |received_payload|
        block.call received_payload[:error]
      end

      producer.on_return do
        block.call({error: "No consumers for destination #{destination}"})
      end
    end
  end
end
