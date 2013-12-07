require 'salemove/messaging/message_handlers/base_message_handler'

module Salemove
  module Messaging
    module MessageHandlers
      class StandardMessageHandler < BaseMessageHandler

        def handle_message(payload, msg_handler)
          callback.call payload, msg_handler
        rescue Exception => e
          logger.error "Exception occured while processing message on #{destination}: e"
        end

        def send_response(producer)
          #NOP
        end

      end
    end
  end
end

