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

    def initialize(channel, logger, producer, consumer)
      @channel, @logger = channel, logger
      @producer, @consumer = producer, consumer
      @request_map = Hamster.mutable_hash
      @request_manager = RequestManager.new @request_map, @logger

      @channel.on_return do |reply_code, correlation_id|
        if reply_code == NO_ROUTE
          @request_manager.no_route(correlation_id)
        end
      end

      @listening_for_responses_lock = Mutex.new
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

    private

    def handle_response(payload, delivery)
      correlation_id = delivery.metadata.correlation_id

      if request = @request_map.delete(correlation_id)
        @logger.debug "Got response for request to #{request[:destination]} with correlation_id #{correlation_id}"
        request[:callback].call payload, delivery
      else
        @logger.warn "Got rpc response for correlation_id #{correlation_id} but there is no requester"
        Utils.notify 'NoRequesterForResponse', "Got rpc response but there is no requester", correlation_id: correlation_id
      end
    rescue Exception => e
      destination_report = request ? "to #{request[:destination]}" : ''
      @logger.error "Exception occured while handling the response of request made #{destination_report} with correlation_id #{correlation_id}: #{Utils.format_exception e}"
      Utils.notify_exception(e, destination: request[:destination], correlation_id: correlation_id)
    end

    def ensure_listening_to_responses
      return @listening_for_responses if defined?(@listening_for_responses)

      @listening_for_responses_lock.synchronize do
        @response_queue ||= @channel.queue("", exclusive: true)
        @request_manager.start
        @consumer.response_consume(@response_queue, &method(:handle_response))
        @listening_for_responses = true
      end
    end
  end
end
