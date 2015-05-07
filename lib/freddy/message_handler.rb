class Freddy
  class MessageHandler
    attr_reader :destination, :correlation_id

    def initialize(adapter, delivery)
      @adapter = adapter
      @properties = delivery.properties
      @destination = @properties[:destination]
      @correlation_id = @properties[:correlation_id]
    end

    def success(response = nil)
      @adapter.success(@properties[:reply_to], response)
    end

    def error(error = {error: "Couldn't process message"})
      @adapter.error(@properties[:reply_to], error)
    end
  end
end
