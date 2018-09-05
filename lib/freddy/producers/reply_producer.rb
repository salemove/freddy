# frozen_string_literal: true

class Freddy
  module Producers
    class ReplyProducer
      CONTENT_TYPE = 'application/json'

      def initialize(channel, logger)
        @logger = logger
        @exchange = channel.default_exchange
      end

      def produce(destination, payload, properties)
        if (span = OpenTracing.active_span)
          span.set_tag('message_bus.destination', destination)
        end

        properties = properties.merge(
          routing_key: destination,
          content_type: CONTENT_TYPE
        )

        @exchange.publish Payload.dump(payload), properties
      end
    end
  end
end
