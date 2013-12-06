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
          block.call (parse_payload payload), MessageHandler.new(@channel, delivery_info, properties)
        end
        @logger.debug "Consuming messages on #{queue.name}"
        ConsumerHandler.new consumer
      end

      def consume_with_ack(destination, &block)
        request = Request.new(@channel)
        request.respond_to destination do |request, msg_handler|
          block.call request, msg_handler
          error = msg_handler.acknowledger.error
          @logger.warn "Consumer failed to acknowledge message on #{destination}: #{error}" if error
          {error: error}
        end
      end

      private

      def parse_payload(payload)
        if payload == 'null'
          {}
        else
          Messaging.symbolize_keys(JSON(payload))
        end
      end

      def create_queue(destination)
        @channel.queue(destination)
      end

    end
  end
end