module Salemove
  module Messaging
    module MessageHandlers
      class StandardMessageHandler < Struct.new(:callback, :destination, :logger)

         def handle_message(payload, msg_handler)
          callback.call payload, msg_handler
        end

        def send_response(producer)
          #NOP
        end

      end
    end
  end
end

