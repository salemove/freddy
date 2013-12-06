require 'salemove/messaging/producer'
require 'salemove/messaging/consumer'
require 'salemove/messaging/message_handlers/request_handler'
require 'salemove/messaging/message_handlers/ack_message_handler'
require 'salemove/messaging/message_handlers/standard_message_handler'
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

      def request(destination, payload, timeout_seconds = 3, options={}, &block)
        raise EmptyRequest unless block
        listen_for_responses unless @listening_for_responses
        correlation_id = SecureRandom.uuid
        timeout = Time.now + timeout_seconds
        @request_map[correlation_id] = { callback: block, destination: destination, timeout: timeout}
        @logger.debug "Publishing request to #{destination}, waiting for response on #{@response_queue.name} with correlation_id #{correlation_id}"
        @producer.produce destination, payload, options.merge(correlation_id: correlation_id, reply_to: @response_queue.name, mandatory: true)
      end

      def respond_to(destination, &block)
        raise EmptyResponder unless block
        @response_queue = create_response_queue unless @response_queue
        @logger.debug "Listening for requests on #{destination}"
        responder_handler = @consumer.basic_consume destination do |payload, msg_handler|
          handler = get_message_handler(msg_handler.properties)
          handle_request payload, msg_handler, handler.new(block, destination, @logger)
        end
        responder_handler
      end

      private

      def create_response_queue
        @channel.queue("", auto_delete: true)
      end

      def get_message_handler(properties)
        if properties[:headers] and properties[:headers]['message_with_ack']
          handler = MessageHandlers::AckMessageHandler
        elsif properties[:correlation_id]
          handler = MessageHandlers::RequestHandler
        else 
          handler = MessageHandlers::StandardMessageHandler
        end 
      end

      def handle_request(payload, msg_handler, handler)
        handler.handle_message payload, msg_handler
        handler.send_response @producer
      end

      def handle_response(payload, msg_handler)
        correlation_id = msg_handler.properties[:correlation_id]
        request = @request_map[correlation_id]
        if request
          @logger.debug "Got response for request to #{request[:destination]} with correlation_id #{correlation_id}"
          @request_map.delete correlation_id
          request[:callback].call payload, msg_handler
        else
          @logger.warn "Got rpc response for correlation_id #{correlation_id} but there is no requester"
        end
      rescue Exception => e
        @logger.error "Exception occured while handling the response of request made to #{request[:destination]} with correlation_id #{correlation_id}: #{Messagging.format_backtrace(e.backtrace)}"
      end

      def listen_for_responses
        @timeout_thread = Thread.new do
          while true do 
            now = Time.now
            begin
              @request_map.each do |key, value|
                if now > value[:timeout]
                  @logger.warn "Request #{key} timed out"
                  value[:callback].call({error: 'Timed out waiting for response'}, nil)
                  @request_map.delete key
                end
              end
            rescue Exception => e 
              puts e
            end
            sleep 0.1
          end 
        end
        @response_queue = create_response_queue unless @response_queue
        @consumer.basic_consume_from_queue @response_queue do |payload, msg_handler|
          handle_response payload, msg_handler
        end
        @listening_for_responses = true
      end

    end
  end
end