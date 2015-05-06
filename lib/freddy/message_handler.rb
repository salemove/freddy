class Freddy
  class MessageHandler
    attr_reader :destination, :correlation_id

    def initialize(adapter, delivery)
      @adapter = adapter
      @properties = delivery.properties
      @destination = @properties[:destination]
      @correlation_id = @properties[:correlation_id]
    end

    def ack(response = nil)
      @adapter.ack(@properties[:reply_to], response)
    end

    def nack(error = "Couldn't process message")
      @adapter.nack(@properties[:reply_to], error: error)
    end
  end
end
