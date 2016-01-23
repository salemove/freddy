class Freddy
  module MessageHandlerAdapters
    class Factory
      def initialize(producer)
        @standard_message_handler = StandardMessageHandler.new
        @request_handler = RequestHandler.new(producer)
      end

      def for(delivery)
        if delivery.type == 'request'
          @request_handler
        else
          @standard_message_handler
        end
      end
    end

    class StandardMessageHandler
      def success(*)
        # NOP
      end

      def error(*)
        # NOP
      end
    end

    class RequestHandler
      def initialize(producer)
        @producer = producer
      end

      def success(delivery, response)
        send_response(delivery, response, type: 'success')
      end

      def error(delivery, response)
        send_response(delivery, response, type: 'error')
      end

      private

      def send_response(delivery, response, opts = {})
        @producer.produce delivery.reply_to.force_encoding('utf-8'), response, {
          correlation_id: delivery.correlation_id
        }.merge(opts)
      end
    end
  end
end
