class Freddy
  module MessageHandlers
    def self.for_type(type)
      type == 'ack' ? RequestHandler : StandardMessageHandler
    end

    class BaseMessageHandler
      def initialize(producer, logger)
        @producer = producer
        @logger = logger
      end

      def handle_message(payload, msg_handler, &block)
        raise NotImplementedError
      end

      def ack
        raise NotImplementedError
      end

      def nack
        raise NotImplementedError
      end
    end

    class StandardMessageHandler < BaseMessageHandler
      def handle_message(payload, msg_handler, &block)
        block.call payload, msg_handler
      rescue Exception => e
        destination = msg_handler.destination
        @logger.error "Exception occured while processing message from #{destination}: #{Freddy.format_exception(e)}"
        Freddy.notify_exception(e, destination: destination)
      end

      def ack(*)
        # NOP
      end

      def nack(*)
        # NOP
      end
    end

    class RequestHandler < BaseMessageHandler
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
        Freddy.notify_exception(e, destination: msg_handler.destination, correlation_id: @correlation_id)
      end

      def ack(reply_to, response)
        send_response(reply_to, response, type: 'ack')
      end

      def nack(reply_to, response)
        send_response(reply_to, response, type: 'nack')
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
