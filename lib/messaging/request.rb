require_relative 'producer'
require_relative 'consumer'
require_relative 'request_timeout_clearer'
require_relative 'sync_response_container'
require_relative 'message_handlers/request_handler'
require_relative 'message_handlers/ack_message_handler'
require_relative 'message_handlers/standard_message_handler'
require 'securerandom'

module Messaging
  class Request

    class EmptyRequest < Exception
    end

    class EmptyResponder < Exception
    end

    def initialize(channel = Freddy.channel, logger = Freddy.logger)
      @channel, @logger = channel, logger
      @producer, @consumer = Producer.new(channel, logger), Consumer.new(channel, logger)
      @listening_for_responses = false
      @request_map = {}
    end

    def sync_request(destination, payload, timeout_seconds = 3, options={})
      container = SyncResponseContainer.new
      async_request destination, payload, timeout_seconds, options, &container
      container.wait_for_response
    end

    def async_request(destination, payload, timeout_seconds = 3, options={}, &block)
      listen_for_responses unless @listening_for_responses
      correlation_id = SecureRandom.uuid
      timeout = Time.now + timeout_seconds
      @request_map[correlation_id] = { callback: block, destination: destination, timeout: timeout}
      @logger.debug "Publishing request to #{destination}, waiting for response on #{@response_queue.name} with correlation_id #{correlation_id}"
      @producer.produce destination, payload, options.merge(correlation_id: correlation_id, reply_to: @response_queue.name, mandatory: true)
    end

    def respond_to(destination, block_thread, &block)
      raise EmptyResponder unless block
      @response_queue = create_response_queue unless @response_queue
      @logger.debug "Listening for requests on #{destination}"
      responder_handler = @consumer.consume destination, { block: block_thread } do |payload, msg_handler|
        handler = get_message_handler(msg_handler.properties)
        handle_request payload, msg_handler, handler.new(block, destination, @logger)
      end
      responder_handler
    end

    private

    def create_response_queue
      @channel.queue("", exclusive: true)
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
      @logger.error "Exception occured while handling the response of request made to #{request[:destination]} with correlation_id #{correlation_id}: #{Freddy.format_exception e}"
    end

    def listen_for_responses
      @timeout_clearer = RequestTimeoutClearer.new @request_map, @logger unless @timeout_clearer
      @response_queue = create_response_queue unless @response_queue
      @consumer.consume_from_queue @response_queue do |payload, msg_handler|
        handle_response payload, msg_handler
      end
    end

  end
end
