class Freddy
  class Delivery
    attr_reader :routing_key, :payload

    def initialize(payload, metadata, routing_key)
      @payload = payload
      @metadata = metadata
      @routing_key = routing_key
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
  end
end
