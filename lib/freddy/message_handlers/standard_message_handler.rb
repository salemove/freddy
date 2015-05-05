require_relative 'base_message_handler'

class Freddy
  module MessageHandlers
    class StandardMessageHandler < BaseMessageHandler

      def handle_message(payload, msg_handler)
        callback.call payload, msg_handler
      rescue Exception => e
        logger.error "Exception occured while processing message on #{destination}: #{Freddy.format_exception e }"
        Freddy.notify_exception(e, destination: destination)
      end

      def send_response(producer)
        #NOP
      end

    end
  end
end
