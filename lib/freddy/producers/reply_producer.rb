class Freddy
  module Producers
    class ReplyProducer
      CONTENT_TYPE = 'application/json'.freeze

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
      end

      def produce(destination, payload, properties)
        Freddy.trace.log_kv event: 'Sending response', queue: destination, payload: payload

        properties = properties.merge(
          routing_key: destination,
          content_type: CONTENT_TYPE
        )

        @exchange.publish Payload.dump(payload), properties
      end
    end
  end
end
