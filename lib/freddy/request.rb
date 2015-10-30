require_relative 'producer'
require_relative 'consumer'
require_relative 'request_manager'
require_relative 'sync_response_container'
require_relative 'message_handlers'
require 'thread'
require 'securerandom'
require 'hamster/mutable_hash'

class Freddy
  class Request
    NO_ROUTE = 312

    class EmptyRequest < Exception
    end

    class EmptyResponder < Exception
    end

    def initialize(channel, logger, producer, consumer)
      @channel, @logger = channel, logger
      @producer, @consumer = producer, consumer
      @request_map = Hamster.mutable_hash
      @request_manager = RequestManager.new @request_map, @logger

      @producer.on_return do |reply_code, correlation_id|
        if reply_code == NO_ROUTE
          @request_manager.no_route(correlation_id)
        end
      end

      @listening_for_responses_lock = Mutex.new
      @response_queue_lock = Mutex.new
    end

    def sync_request(destination, payload, opts)
      timeout_seconds = opts.fetch(:timeout)
      container = SyncResponseContainer.new
      async_request destination, payload, opts, &container
      container.wait_for_response(timeout_seconds + 0.1)
    end

    def async_request(destination, payload, options, &block)
      timeout = options.fetch(:timeout)
      delete_on_timeout = options.fetch(:delete_on_timeout)
      options.delete(:timeout)
      options.delete(:delete_on_timeout)

      ensure_listening_to_responses

      correlation_id = SecureRandom.uuid
      @request_map.store(correlation_id, callback: block, destination: destination, timeout: Time.now + timeout)

      @logger.debug "Publishing request to #{destination}, waiting for response on #{@response_queue.name} with correlation_id #{correlation_id}"

      if delete_on_timeout
        options[:expiration] = (timeout * 1000).to_i
      end

      @producer.produce destination, payload, options.merge(
        correlation_id: correlation_id, reply_to: @response_queue.name,
        mandatory: true, type: 'request'
      )
    end

    def respond_to(destination, &block)
      raise EmptyResponder unless block

      ensure_response_queue_exists
      @logger.info "Listening for requests on #{destination}"
      responder_handler = @consumer.consume destination do |payload, delivery|
        handler = MessageHandlers.for_type(delivery.metadata.type).new(@producer, destination, @logger)

        msg_handler = MessageHandler.new(handler, delivery)
        handler.handle_message payload, msg_handler, &block
      end
      responder_handler
    end

    private

    def create_response_queue
      AdaptiveQueue.new @channel.queue("", exclusive: true)
    end

    def handle_response(payload, delivery)
      correlation_id = delivery.metadata.correlation_id
      request = @request_map[correlation_id]
      if request
        @logger.debug "Got response for request to #{request[:destination]} with correlation_id #{correlation_id}"
        @request_map.delete correlation_id
        request[:callback].call payload, delivery
      else
        @logger.warn "Got rpc response for correlation_id #{correlation_id} but there is no requester"
        Freddy.notify 'NoRequesterForResponse', "Got rpc response but there is no requester", correlation_id: correlation_id
      end
    rescue Exception => e
      destination_report = request ? "to #{request[:destination]}" : ''
      @logger.error "Exception occured while handling the response of request made #{destination_report} with correlation_id #{correlation_id}: #{Freddy.format_exception e}"
      Freddy.notify_exception(e, destination: request[:destination], correlation_id: correlation_id)
    end

    def ensure_response_queue_exists
      @response_queue_lock.synchronize do
        @response_queue ||= create_response_queue
      end
    end

    def ensure_listening_to_responses
      @listening_for_responses_lock.synchronize do
        if @listening_for_responses
          true
        else
          ensure_response_queue_exists
          @request_manager.start
          @consumer.dedicated_consume @response_queue do |payload, delivery|
            handle_response payload, delivery
          end
          @listening_for_responses = true
        end
      end
    end
  end
end
