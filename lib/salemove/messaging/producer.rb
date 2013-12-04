require 'salemove/messaging/request'

module Salemove
  module Messaging
    class Producer

      class EmptyAckHandler < Exception 
      end

      def initialize(channel = Messaging.channel, logger=Messaging.logger)
        @channel, @logger = channel, logger
        @exchange = @channel.default_exchange
      end

      def produce(destination, payload, properties={})
        @logger.debug "Producing message to #{destination}"
        @exchange.publish payload.to_json, properties.merge(routing_key: destination, content_type: 'application/json')
      end

      def produce_with_ack(destination, payload, &block)
        raise EmptyAckHandler unless block
        req = Request.new(@channel)
        producer = req.request destination, payload, mandatory: true do |payload|
          block.call payload[:error]
        end

        producer.on_return do 
          block.call "No consumers for destination #{destination}"
        end
      end

    end
  end
end