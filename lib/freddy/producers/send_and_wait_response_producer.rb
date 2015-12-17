class Freddy
  module Producers
    class SendAndWaitResponseProducer
      CONTENT_TYPE = 'application/json'.freeze

      def initialize(channel, logger)
        @logger = logger
        @channel = channel

        @request_manager = RequestManager.new(@logger)

        @exchange = @channel.default_exchange
        @topic_exchange = @channel.topic Freddy::FREDDY_TOPIC_EXCHANGE_NAME

        @channel.on_no_route do |correlation_id|
          @request_manager.no_route(correlation_id)
        end

        @response_queue = @channel.queue("", exclusive: true)
        @request_manager.start

        @response_consumer = Consumers::ResponseConsumer.new(@logger)
        @response_consumer.consume(@response_queue, &method(:handle_response))
      end

      def produce(destination, payload, properties)
        timeout_seconds = properties.fetch(:timeout)
        container = SyncResponseContainer.new
        async_request destination, payload, properties, &container
        container.wait_for_response(timeout_seconds + 0.1)
      end

      private

      def async_request(destination, payload, timeout:, delete_on_timeout:, **properties, &block)
        correlation_id = SecureRandom.uuid
        @request_manager.store(correlation_id, callback: block, destination: destination, timeout: Time.now + timeout)

        if delete_on_timeout
          properties[:expiration] = (timeout * 1000).to_i
        end

        properties = properties.merge(
          routing_key: destination, content_type: CONTENT_TYPE,
          correlation_id: correlation_id, reply_to: @response_queue.name,
          mandatory: true, type: 'request'
        )
        json_payload = Payload.dump(payload)

        @logger.debug "Publishing request with payload #{payload.inspect} "\
                      "to #{destination}, waiting for response on "\
                      "#{@response_queue.name} with correlation_id #{correlation_id}"

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock these.
        @topic_exchange.publish json_payload, properties.dup
        @exchange.publish json_payload, properties.dup
      end

      def handle_response(delivery)
        correlation_id = delivery.correlation_id

        if request = @request_manager.delete(correlation_id)
          process_response(request, delivery)
        else
          warning = "Got rpc response for correlation_id #{correlation_id} "\
                    "but there is no requester"
          @logger.warn message
          Utils.notify 'NoRequesterForResponse', warning, correlation_id: correlation_id
        end
      end

      def process_response(request, delivery)
        @logger.debug "Got response for request to #{request[:destination]} "\
                      "with correlation_id #{delivery.correlation_id}"
        request[:callback].call(delivery.payload, delivery)
      rescue => e
        @logger.error "Exception occured while handling the response of "\
                      "request made to #{request[:destination]} with "\
                      "correlation_id #{correlation_id}: #{Utils.format_exception(e)}"
        Utils.notify_exception(e, destination: request[:destination], correlation_id: correlation_id)
      end
    end
  end
end
