class Freddy
  class MessageHandler
    attr_reader :correlation_id

    def initialize(adapter, delivery)
      @adapter = adapter
      @delivery = delivery
      @correlation_id = @delivery.correlation_id
    end

    def success(response = nil)
      @adapter.success(@delivery.reply_to, response)
    end

    def error(error = {error: "Couldn't process message"})
      @adapter.error(@delivery.reply_to, error)
    end
  end
end
