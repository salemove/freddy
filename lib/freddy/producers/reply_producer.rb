class Freddy
  module Producers
    class ReplyProducer
      CONTENT_TYPE = 'application/json'.freeze

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
      end

      def produce(destination, payload, properties)
        Producers.log_send_event(@logger, payload, destination)

        properties = properties.merge(
          routing_key: destination, content_type: CONTENT_TYPE
        )

        @exchange.publish Payload.dump(payload), properties
      end
    end
  end
end
