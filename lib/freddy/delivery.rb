class Freddy
  class Delivery
    attr_reader :routing_key, :payload, :tag

    def initialize(payload, metadata, routing_key, tag)
      @payload = payload
      @metadata = metadata
      @routing_key = routing_key
      @tag = tag
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

    def build_trace(operation_name, tags: {}, force_follows_from: false)
      carrier = TraceCarrier.new(@metadata)
      parent = OpenTracing.global_tracer.extract(OpenTracing::FORMAT_TEXT_MAP, carrier)

      references =
        if !parent
          []
        elsif force_follows_from
          [OpenTracing::Reference.follows_from(parent)]
        else
          [OpenTracing::Reference.child_of(parent)]
        end

      OpenTracing.start_active_span(operation_name, references: references, tags: tags)
    end
  end
end
