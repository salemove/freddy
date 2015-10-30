class Freddy
  class MessageHandler
    attr_reader :destination, :correlation_id

    def initialize(adapter, delivery)
      @adapter = adapter
      @metadata = delivery.metadata
      @correlation_id = @metadata.correlation_id
    end

    def success(response = nil)
      @adapter.success(@metadata.reply_to, response)
    end

    def error(error = {error: "Couldn't process message"})
      @adapter.error(@metadata.reply_to, error)
    end
  end
end
