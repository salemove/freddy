class Freddy
  class Delivery
    attr_reader :metadata, :routing_key

    def initialize(metadata, routing_key)
      @metadata = metadata
      @routing_key = routing_key
    end
  end
end
