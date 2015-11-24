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

    def on_return(&block)
      if @exchange.respond_to? :on_return # Bunny
        @exchange.on_return do |return_info, properties, content|
          block.call(return_info[:reply_code], properties[:correlation_id])
        end
      elsif @channel.respond_to? :on_return # Hare
        @channel.on_return do |reply_code, _, exchange_name, _, properties|
          if exchange_name != Freddy::FREDDY_TOPIC_EXCHANGE_NAME
            block.call(reply_code, properties.correlation_id)
          end
        end
      else
        raise OnReturnNotImplemented.new "AMQP implementation doesn't implement on_return"
      end
    end
  end
end
