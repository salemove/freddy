require_relative 'request'
require 'json'

class Freddy
  class Producer
    OnReturnNotImplemented = Class.new(NoMethodError)

    CONTENT_TYPE = 'application/json'.freeze

    def initialize(channel, logger)
      @channel, @logger = channel, logger
      @exchange = @channel.default_exchange
      @topic_exchange = @channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
    end

    def produce(destination, payload, properties={})
      @logger.debug "Producing message #{payload.inspect} to #{destination}"

      properties = properties.merge(routing_key: destination, content_type: CONTENT_TYPE)
      json_payload = Payload.dump(payload)

      @topic_exchange.publish json_payload, properties.dup
      @exchange.publish json_payload, properties.dup
    end
  end
end
