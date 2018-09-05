# frozen_string_literal: true

class Freddy
  class MessageHandler
    def initialize(adapter, delivery)
      @adapter = adapter
      @delivery = delivery
    end

    def success(response = nil)
      @adapter.success(@delivery, response)
    end

    def error(response = { error: "Couldn't process message" })
      @adapter.error(@delivery, response)
    end
  end
end
