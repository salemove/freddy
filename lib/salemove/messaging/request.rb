require 'salemove/messaging/producer'
require 'salemove/messaging/consumer'
require 'salemove/messaging/consumer_handler'
require 'securerandom'

module Salemove
  module Messaging
    class Request

      class EmptyRequest < Exception 
      end

      class EmptyResponder < Exception
      end

      def initialize(channel = Messaging.channel, logger = Messaging.logger)
        @channel, @logger = channel, logger
        @producer, @consumer = Producer.new(channel), Consumer.new(channel)
        @listening_for_responses = false
        @request_map = {}
      end

      def request(destination, payload, options={}, &block)
        raise EmptyRequest unless block
        listen_for_responses unless @listening_for_responses
        correlation_id = SecureRandom.uuid
        @request_map[correlation_id] = { callback: block, destination: destination }
        @logger.debug "Publishing request to #{destination}, waiting for response on #{@response_queue.name} with correlation_id #{correlation_id}"
        @producer.produce destination, payload, options.merge(correlation_id: correlation_id, reply_to: @response_queue.name)
      end

      def respond_to(destination, &block)
        raise EmptyResponder unless block
        @response_queue = create_response_queue unless @response_queue
        @logger.debug "Listening for requests on #{destination}"
        responder = @consumer.consume destination do |payload, message_handler|
          @logger.debug "Got request on #{destination} with correlation_id #{message_handler.properties[:correlation_id]}"
          handle_request payload, message_handler.properties, block
        end
        ConsumerHandler.new responder
      end

      private 

      def create_response_queue
        @channel.queue("", exclusive: true)
      end

      def handle_request(payload, properties, block)
        correlation_id = properties[:correlation_id]
        if !correlation_id
          @logger.error "Received request without correlation_id"
          return 
        end
        response = block.call payload
        @producer.produce properties[:reply_to], response, correlation_id: correlation_id
      rescue Exception => e
        @logger.error "Exception occured while handling the request with correlation_id #{correlation_id}: #{Messagging.format_backtrace(e.backtrace)}"
      end

      def handle_response(payload, listen_ops)
        correlation_id = listen_ops.properties[:correlation_id]
        request = @request_map[correlation_id]
        if request
          @logger.debug "Got response for request to #{request[:destination]} with correlation_id #{correlation_id}"
          @request_map.delete correlation_id
          request[:callback].call payload, listen_ops
        else
          @logger.warn "Got rpc response for correlation_id #{correlation_id} but there is no requester"
        end
      rescue Exception => e
        @logger.error "Exception occured while handling the response of request made to #{request[:destination]} with correlation_id #{correlation_id}: #{Messagging.format_backtrace(e.backtrace)}"
      end

      def listen_for_responses
        @response_queue = create_response_queue unless @response_queue
        @consumer.consume_from_queue @response_queue do |payload, ops|
          handle_response payload, ops
        end
        @listening_for_responses = true
      end

    end
  end
end