class Freddy
  module Producers
    class SendAndForgetProducer
      CONTENT_TYPE = 'application/json'.freeze

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
        @topic_exchange = channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
      end

      def produce(destination, payload, properties)
        Producers.log_send_event(@logger, payload, destination)

        properties = properties.merge(routing_key: destination, content_type: CONTENT_TYPE)
        json_payload = Payload.dump(payload)

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock these.
        @topic_exchange.publish json_payload, properties.dup
        @exchange.publish json_payload, properties.dup
      end
    end
  end
end
