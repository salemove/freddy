# frozen_string_literal: true

class Freddy
  module Tracing
    # NOTE: Make sure you finish the span youself.
    def self.span_for_produce(exchange, routing_key, payload, correlation_id: nil, timeout_in_seconds: nil)
      destination = exchange.name
      destination_kind = exchange.type == :direct ? 'queue' : 'topic'

      attributes = {
        'payload.type' => (payload[:type] || 'unknown').to_s,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_SYSTEM => 'rabbitmq',
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_RABBITMQ_ROUTING_KEY => routing_key,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_DESTINATION => destination,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_DESTINATION_KIND => destination_kind,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_OPERATION => 'send'
      }

      attributes['freddy.timeout_in_seconds'] = timeout_in_seconds if timeout_in_seconds

      if correlation_id
        attributes[OpenTelemetry::SemanticConventions::Trace::MESSAGING_CONVERSATION_ID] = correlation_id
      end

      Freddy.tracer.start_span(
        ".#{routing_key} send",
        kind: OpenTelemetry::Trace::SpanKind::PRODUCER,
        attributes: attributes
      )
    end

    def self.inject_tracing_information_to_properties!(properties)
      properties[:headers] ||= {}
      OpenTelemetry.propagation.inject(properties[:headers])
    end
  end
end
