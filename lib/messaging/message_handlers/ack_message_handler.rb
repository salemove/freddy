require_relative 'base_message_handler'

module Messaging
  module MessageHandlers
    class AckMessageHandler < BaseMessageHandler

      attr_reader :response

      def handle_message(payload, msg_handler)
        logger.debug "Received message on #{destination}"
        initialize_properties msg_handler
        callback.call payload, msg_handler
        error = msg_handler.error
        logger.debug "Responder failed to acknowledge message on #{destination}: #{error}" if error
        @response = {error: error}
      rescue Exception => e
        message = "Exception occured while processing a message that awaits acknowledgement"
        logger.error "#{message} on #{destination} : #{Freddy.format_exception e}"
        Freddy.notify_exception(e, message: message, destination: destination)
      end

    end
  end
end

