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

      def produce(destination, payload, properties)
        span = OpenTracing.start_span("freddy:notify:#{destination}",
                                      tags: {
                                        'message_bus.destination' => destination,
                                        'component' => 'freddy',
                                        'span.kind' => 'producer' # Message Bus
                                      })

        properties = properties.merge(
          routing_key: destination,
          content_type: CONTENT_TYPE
        )
        OpenTracing.global_tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, TraceCarrier.new(properties))
        json_payload = Payload.dump(payload)

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock these.
        @topic_exchange.publish json_payload, properties.dup
        @exchange.publish json_payload, properties.dup
      ensure
        # We don't know how many listeners there are and we do not know when
        # this message gets processed. Instead we close the span immediately.
        # Listeners should use FollowsFrom to add trace information.
        # https://github.com/opentracing/specification/blob/master/specification.md
        span.finish
      end
    end
  end
end
