require 'messaging/request'
require 'json'

module Messaging
  class Producer

    class EmptyAckHandler < Exception 
    end

    def initialize(channel = Freddy.channel, logger=Freddy.logger)
      @channel, @logger = channel, logger
      @exchange = @channel.default_exchange
    end

    def produce(destination, payload, properties={})
      @logger.debug "Producing message to #{destination}"
      @exchange.publish payload.to_json, properties.merge(routing_key: destination, content_type: 'application/json')
    end

    def produce_with_ack(destination, payload, timeout_seconds = 3, properties={}, &block)
      raise EmptyAckHandler unless block
      req = Request.new(@channel)
      producer = req.request destination, payload, timeout_seconds, properties.merge(mandatory: true, headers: {message_with_ack: true}) do |payload|
        block.call payload[:error]
      end

      producer.on_return do 
        block.call({error: "No consumers for destination #{destination}"})
      end
    end

  end
end
