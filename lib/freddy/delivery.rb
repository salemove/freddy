# frozen_string_literal: true

class Freddy
  class Delivery
    attr_reader :routing_key, :payload, :tag

    def initialize(payload, metadata, routing_key, tag, exchange)
      @payload = payload
      @metadata = metadata
      @routing_key = routing_key
      @tag = tag
      @exchange = exchange
    end

    def correlation_id
      @metadata.correlation_id
    end

    def type
      @metadata.type
    end

    def reply_to
      @metadata.reply_to
    end

    def in_span(&block)
      name = "#{Tracing.span_destination(@exchange, @routing_key)} process"
      kind = OpenTelemetry::Trace::SpanKind::CONSUMER
      producer_context = OpenTelemetry.propagation.extract(@metadata[:headers] || {})

      OpenTelemetry::Context.with_current(producer_context) do
        Freddy.tracer.in_span(name, attributes: span_attributes, kind: kind, &block)
      end
    end

    private

    def span_attributes
      destination_kind = @exchange == '' ? 'queue' : 'topic'

      attributes = {
        'payload.type' => (@payload[:type] || 'unknown').to_s,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_SYSTEM => 'rabbitmq',
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_DESTINATION => @exchange,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_DESTINATION_KIND => destination_kind,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_RABBITMQ_ROUTING_KEY => @routing_key,
        OpenTelemetry::SemanticConventions::Trace::MESSAGING_OPERATION => 'process'
      }

      # There's no correlation_id when a message was sent using
      # `Freddy#deliver`.
      if correlation_id
        attributes[OpenTelemetry::SemanticConventions::Trace::MESSAGING_CONVERSATION_ID] = correlation_id
      end

      attributes
    end
  end
end
