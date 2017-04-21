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
      parent =
        if expecting_response? && !force_follows_from
          OpenTracing.global_tracer.extract(OpenTracing::FORMAT_TEXT_MAP, carrier)
        else
          nil
        end

      # Creating a child span when the message sender is expecting a response.
      # Otherwise creating a new trace because the OpenTracing client does not
      # support FollowsFrom yet.
      OpenTracing.start_span(operation_name, child_of: parent, tags: tags)
    end

    private

    def expecting_response?
      type == 'request'
    end
  end
end
