# frozen_string_literal: true

class Freddy
  module Producers
    class ReplyProducer
      CONTENT_TYPE = 'application/json'

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
      end

      def produce(routing_key, payload, properties)
        span = Tracing.span_for_produce(
          @exchange,
          routing_key,
          payload,
          correlation_id: properties[:correlation_id]
        )

        properties = properties.merge(
          routing_key:,
          content_type: CONTENT_TYPE
        )
        Tracing.inject_tracing_information_to_properties!(properties, span)

        @exchange.publish Payload.dump(payload), properties
      ensure
        # We won't wait for a reply. Just finish the span immediately.
        span.finish
      end
    end
  end
end
