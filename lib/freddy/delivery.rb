class Freddy
  class Delivery
    attr_reader :routing_key, :payload, :tag, :trace

    def initialize(payload, metadata, routing_key, tag)
      @payload = payload
      @metadata = metadata
      @routing_key = routing_key
      @tag = tag
      @trace = build_trace(metadata.headers || {})
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

    private

    def build_trace(headers)
      if headers['x-trace-id'] && headers['x-span-id']
        Traces::Trace.build_from_existing_trace(
          id: headers['x-trace-id'],
          parent_id: headers['x-span-id']
        )
      else
        Traces::Trace.build
      end
    end
  end
end
