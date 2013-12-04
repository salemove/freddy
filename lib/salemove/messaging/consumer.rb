require 'salemove/messaging/consumer_handler'
require 'salemove/messaging/message_handler'
require 'salemove/messaging/request'


module Salemove
  module Messaging
    class Consumer

      class EmptyConsumer < Exception
      end

      def initialize(channel = Messaging.channel, logger=Messaging.logger)
        @channel, @logger = channel, logger
      end

      def consume(destination, &block)
        consume_from_queue create_queue(destination), &block
      end

      def consume_from_queue(queue, &block)
        raise EmptyConsumer unless block
        consumer = queue.subscribe do |delivery_info, properties, payload|
          @logger.debug "Received message on #{queue.name}"
          block.call Messaging.symbolize_keys(JSON(payload)), MessageHandler.new(@channel, delivery_info, properties)
        end
        @logger.debug "Consuming messages on #{queue.name}"
        ConsumerHandler.new consumer
      end

      def consume_with_ack(destination, &block)
        request = Request.new(@channel)
        request.respond_to destination do |request|
          acknowledger = Acknowledger.new
          begin
            block.call request, acknowledger
          rescue Exception => e
            @logger.error "Consuming with acknowledgement failed on destination #{destination} #{Messaging.format_exception(e)}"
          end
          @logger.warn "Consumer failed to acknowledge message on #{destination}: #{acknowledger.error}" if acknowledger.error
          {error: acknowledger.error}
        end
      end

      private

      class Acknowledger 
        @acked = false

        def ack
          @acked = true
          @error = nil
        end

        def nack(error)
          @acked = false
          @error = error
        end

        def error
          if @error
            @error
          elsif !@acked
            "Consumer didn't manually acknowledge message"
          end
        end
      end

      def create_queue(destination)
        @channel.queue(destination)
      end

    end
  end
end