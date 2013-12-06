require 'salemove/messaging/consumer'
require 'salemove/messaging/producer'
require 'salemove/messaging/request'

module Salemove
  module Messaging
    class Messenger

      def initialize(use_unique_channel = false, logger = Messaging.logger)
        initalize_channel(use_unique_channel)
        @logger = logger
        @consumer, @producer, @request = Consumer.new(@channel, @logger), Producer.new(@channel, @logger), Request.new(@channel, @logger)
      end

      def respond_to(destination, &block)
        @request.respond_to destination, &block
      end

      def produce(destination, payload, properties = {})
        @producer.produce destination, payload, properties
      end

      def produce_with_ack(destination, payload, timeout_seconds = 3, properties = {}, &block)
        @producer.produce_with_ack destination, payload, timeout_seconds, properties, &block
      end

      def produce_with_response(destination, payload, timeout_seconds = 3, options={}, &block)
        @request.request destination, payload, timeout_seconds, options, &block
      end

      private 

      def initalize_channel(use_unique_channel)
        if use_unique_channel
          @channel = Messaging.new_channel
        else
          @channel = Messaging.channel
        end
      end

    end
  end
end