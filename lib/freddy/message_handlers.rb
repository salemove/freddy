class Freddy
  module MessageHandlers
    def self.for_type(type)
      type == 'request' ? RequestHandler : StandardMessageHandler
    end

    class StandardMessageHandler
      def initialize(producer, logger)
        @producer = producer
        @logger = logger
      end

      def handle_message(payload, msg_handler, &block)
        block.call payload, msg_handler
      rescue Exception => e
        @logger.error "Exception occured while processing message from #{Freddy.format_exception(e)}"
        Freddy.notify_exception(e)
      end

      def success(*)
        # NOP
      end

      def error(*)
        # NOP
      end
    end

    class RequestHandler
      def initialize(producer, logger)
        @producer = producer
        @logger = logger
      end

      def handle_message(payload, msg_handler, &block)
        @correlation_id = msg_handler.correlation_id

        if !@correlation_id
          @logger.error "Received request without correlation_id"
          Freddy.notify_exception(e)
        else
          block.call payload, msg_handler
        end
      rescue Exception => e
        @logger.error "Exception occured while handling the request with correlation_id #{@correlation_id}: #{Freddy.format_exception(e)}"
        Freddy.notify_exception(e, correlation_id: @correlation_id)
      end

      def success(reply_to, response)
        send_response(reply_to, response, type: 'success')
      end

      def error(reply_to, response)
        send_response(reply_to, response, type: 'error')
      end

      private

      def send_response(reply_to, response, opts = {})
        @producer.produce reply_to.force_encoding('utf-8'), response, {
          correlation_id: @correlation_id
        }.merge(opts)
      end
    end
  end
end
