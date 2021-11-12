# frozen_string_literal: true

class Freddy
  module Tracing
    RESPONSE_QUEUE_PREFIX = 'amq.gen-'

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
        "#{span_destination(destination, routing_key)} send",
        kind: OpenTelemetry::Trace::SpanKind::PRODUCER,
        attributes: attributes
      )
    end

    def self.span_destination(destination, routing_key)
      if routing_key.to_s.start_with?(RESPONSE_QUEUE_PREFIX)
        "#{destination}.(response queue)"
      else
        "#{destination}.#{routing_key}"
      end
    end

    def self.inject_tracing_information_to_properties!(properties, span)
      context = OpenTelemetry::Trace.context_with_span(span)
      properties[:headers] ||= {}
      OpenTelemetry.propagation.inject(properties[:headers], context: context)
    end
  end
end
