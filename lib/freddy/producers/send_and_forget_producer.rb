# frozen_string_literal: true

class Freddy
  module Producers
    class SendAndForgetProducer
      CONTENT_TYPE = 'application/json'

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
        @topic_exchange = channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME
      end

      def produce(routing_key, payload, properties)
        span = Tracing.span_for_produce(@topic_exchange, routing_key, payload)

        properties = properties.merge(
          routing_key: routing_key,
          content_type: CONTENT_TYPE
        )
        Tracing.inject_tracing_information_to_properties!(properties)

        json_payload = Freddy::Encoding.compress(
          Payload.dump(payload),
          properties[:content_encoding]
        )

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock these.
        @topic_exchange.publish json_payload, properties.dup
        @exchange.publish json_payload, properties.dup
      ensure
        # We don't know how many listeners there are and we do not know when
        # this message gets processed. Instead we close the span immediately.
        span.finish
      end
    end
  end
end
