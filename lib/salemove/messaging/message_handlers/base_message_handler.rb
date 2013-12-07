module Salemove
  module Messaging
    module MessageHandlers
      class BaseMessageHandler < Struct.new(:callback, :destination, :logger)
        attr_reader :properties, :correlation_id

        def initialize_properties(msg_handler)
          @properties = msg_handler.properties
          @correlation_id = properties[:correlation_id]
        end

        def handle_message(payload, msg_handler)
          raise NotImplementedError.new "Must implement handle_message"
        end

        def response
          raise NotImplementedError.new "Must implement response"
        end

        def send_response(producer)
          producer.produce properties[:reply_to], response, correlation_id: correlation_id
        end

      end
    end
  end
end

