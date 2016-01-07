class Freddy
  module Producers
    class ReplyProducer
      CONTENT_TYPE = 'application/json'.freeze

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
      end

      def produce(destination, payload, properties)
        @logger.debug "Sending message #{payload.inspect} to #{destination}"

        properties = properties.merge(
          routing_key: destination, content_type: CONTENT_TYPE
        )

        @exchange.publish Payload.dump(payload), properties
      end
    end
  end
end
