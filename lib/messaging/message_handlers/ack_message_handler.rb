require 'messaging/message_handlers/base_message_handler'

module Messaging
  module MessageHandlers
    class AckMessageHandler < BaseMessageHandler

      attr_reader :response

      def handle_message(payload, msg_handler)
        logger.debug "Received message on #{destination}"
        initialize_properties msg_handler
        callback.call payload, msg_handler
        error = msg_handler.error
        logger.warn "Responder failed to acknowledge message on #{destination}: #{error}" if error
        @response = {error: error}
      rescue Exception => e
        logger.error "Exception occured while processing a message that needs to acknowledge on #{destination} : #{e}"
      end

    end
  end
end

