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

        @response_consumer = Consumers::ResponseConsumer.new(@logger)
        @response_consumer.consume(@channel, @response_queue, &method(:handle_response))
      end

      def produce(destination, payload, timeout_in_seconds:, delete_on_timeout:, **properties)
        correlation_id = SecureRandom.uuid

        span = OpenTracing.start_span("freddy:request:#{destination}",
          tags: {
            'component' => 'freddy',
            'span.kind' => 'client', # RPC
            'payload.type' => payload[:type] || 'unknown',
            'message_bus.destination' => destination,
            'message_bus.response_queue' => @response_queue.name,
            'message_bus.correlation_id' => correlation_id,
            'freddy.timeout_in_seconds' => timeout_in_seconds
          }
        )

        container = SyncResponseContainer.new(
          on_timeout(correlation_id, destination, timeout_in_seconds, span)
        )

        @request_manager.store(correlation_id,
          callback: container,
          span: span,
          destination: destination
        )

        if delete_on_timeout
          properties[:expiration] = (timeout_in_seconds * 1000).to_i
        end

        properties = properties.merge(
          routing_key: destination, content_type: CONTENT_TYPE,
          correlation_id: correlation_id, reply_to: @response_queue.name,
          mandatory: true, type: 'request'
        )
        OpenTracing.global_tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, TraceCarrier.new(properties))
        json_payload = Payload.dump(payload)

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock these.
        @topic_exchange.publish json_payload, properties.dup
        @exchange.publish json_payload, properties.dup

        container.wait_for_response(timeout_in_seconds)
      end

      def handle_response(delivery)
        correlation_id = delivery.correlation_id

        if request = @request_manager.delete(correlation_id)
          process_response(request, delivery)
        else
          message = "Got rpc response for correlation_id #{correlation_id} "\
                    "but there is no requester"
          @logger.warn message
        end
      end

      def process_response(request, delivery)
        @logger.debug "Got response for request to #{request[:destination]} "\
                      "with correlation_id #{delivery.correlation_id}"
        request[:callback].call(delivery.payload, delivery)
      rescue InvalidRequestError => e
        request[:span].set_tag('error', true)
        request[:span].log_kv(
          event: 'invalid request',
          message: e.message,
          'error.object': e
        )
        raise e
      ensure
        request[:span].finish
      end

      def on_timeout(correlation_id, destination, timeout_in_seconds, span)
        Proc.new do
          @logger.warn "Request timed out waiting response from #{destination}"\
                       ", correlation id #{correlation_id}, timeout #{timeout_in_seconds}s"

          @request_manager.delete(correlation_id)
          span.set_tag('error', true)
          span.log_kv(
            event: 'timed out',
            message: "Timed out waiting response from #{destination}"
          )
          span.finish
        end
      end
    end
  end
end
