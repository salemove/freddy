module Salemove
  module Messaging
    module MessageHandlers
      class AckMessageHandler < Struct.new(:callback, :destination, :logger)

        def handle_message(payload, msg_handler)
          @properties = msg_handler.properties
          @correlation_id = @properties[:correlation_id]
          callback.call payload, msg_handler
          error = msg_handler.acknowledger.error
          logger.warn "Consumer failed to acknowledge message on #{destination}: #{error}" if error
          @response = {error: error}
        end

        def send_response(producer)
          producer.produce @properties[:reply_to], @response, correlation_id: @correlation_id
        end

      end
    end
  end
end

