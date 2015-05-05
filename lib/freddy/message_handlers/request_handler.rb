require_relative 'base_message_handler'

class Freddy
  module MessageHandlers
    class RequestHandler < BaseMessageHandler
      attr_reader :response

      def handle_message(payload, msg_handler)
        initialize_properties msg_handler
        logger.debug "Got request on #{destination} with correlation_id #{@correlation_id}"
        if !@correlation_id
          logger.error "Received request without correlation_id"
          Freddy.notify_exception(e)
        else
          callback.call payload, msg_handler
          @response = msg_handler.response
        end
      rescue Exception => e
        logger.error "Exception occured while handling the request with correlation_id #{@correlation_id}: #{Freddy.format_exception e }"
        Freddy.notify_exception(e, destination: destination, correlation_id: @correlation_id)
      end

    end
  end
end
