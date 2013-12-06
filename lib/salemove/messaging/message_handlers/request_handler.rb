module Salemove
  module Messaging
    module MessageHandlers
      class RequestHandler < Struct.new(:callback, :destination, :logger)

        def handle_message(payload, msg_handler)
          @properties = msg_handler.properties
          @correlation_id = @properties[:correlation_id]
          logger.debug "Got request on #{destination} with correlation_id #{@correlation_id}"
          if !@correlation_id
            logger.error "Received request without correlation_id"
          else
            @response = callback.call payload, msg_handler
          end
        rescue Exception => e
          logger.error "Exception occured while handling the request with correlation_id #{correlation_id}: #{Messagging.format_backtrace(e.backtrace)}"
        end

        def send_response(producer)
          producer.produce @properties[:reply_to], @response, correlation_id: @correlation_id
        end
      end
    end
  end
end

