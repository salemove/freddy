require 'messaging/consumer'
require 'messaging/producer'
require 'messaging/request'

module Messaging
  class Freddy

    def initialize(use_unique_channel = false, logger = Messaging.logger)
      initalize_channel(use_unique_channel)
      @logger = logger
      @consumer, @producer, @request = Consumer.new(@channel, @logger), Producer.new(@channel, @logger), Request.new(@channel, @logger)
    end

    def respond_to(destination, &block)
      @request.respond_to destination, &block
    end

    def produce(destination, payload)
      @producer.produce destination, payload
    end

    def produce_with_ack(destination, payload, timeout_seconds = 3, &block)
      @producer.produce_with_ack destination, payload, timeout_seconds, &block
    end

    def produce_with_response(destination, payload, timeout_seconds = 3,&block)
      @request.request destination, payload, timeout_seconds, &block
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
