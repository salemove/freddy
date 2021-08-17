# frozen_string_literal: true

class Freddy
  module Producers
    class SendAndWaitResponseProducer
      CONTENT_TYPE = 'application/json'

      def initialize(channel, logger)
        @logger = logger
        @channel = channel

        @request_manager = RequestManager.new(@logger)

        @exchange = @channel.default_exchange

        @channel.on_no_route do |correlation_id|
          @request_manager.no_route(correlation_id)
        end

        @response_queue = @channel.queue('', exclusive: true)

        @response_consumer = Consumers::ResponseConsumer.new(@logger)
        @response_consumer.consume(@channel, @response_queue, &method(:handle_response))
      end

      def produce(routing_key, payload, timeout_in_seconds:, delete_on_timeout:, **properties)
        correlation_id = SecureRandom.uuid

        span = Tracing.span_for_produce(
          @exchange,
          routing_key,
          payload,
          correlation_id: correlation_id, timeout_in_seconds: timeout_in_seconds
        )

        container = SyncResponseContainer.new(
          on_timeout(correlation_id, routing_key, timeout_in_seconds, span)
        )

        @request_manager.store(correlation_id,
                               callback: container,
                               span: span,
                               destination: routing_key)

        properties[:expiration] = (timeout_in_seconds * 1000).to_i if delete_on_timeout

        properties = properties.merge(
          routing_key: routing_key, content_type: CONTENT_TYPE,
          correlation_id: correlation_id, reply_to: @response_queue.name,
          mandatory: true, type: 'request'
        )
        Tracing.inject_tracing_information_to_properties!(properties)

        # Connection adapters handle thread safety for #publish themselves. No
        # need to lock this.
        @exchange.publish Payload.dump(payload), properties.dup

        container.wait_for_response(timeout_in_seconds)
      end

      def handle_response(delivery)
        correlation_id = delivery.correlation_id

        if (request = @request_manager.delete(correlation_id))
          process_response(request, delivery)
        else
          message = "Got rpc response for correlation_id #{correlation_id} "\
                    'but there is no requester'
          @logger.warn message
        end
      end

      def process_response(request, delivery)
        @logger.debug "Got response for request to #{request[:destination]} "\
                      "with correlation_id #{delivery.correlation_id}"
        request[:callback].call(delivery.payload, delivery)
      rescue InvalidRequestError => e
        request[:span].record_exception(e)
        request[:span].status = OpenTelemetry::Trace::Status.error
        raise e
      ensure
        request[:span].finish
      end

      def on_timeout(correlation_id, routing_key, timeout_in_seconds, span)
        proc do
          @logger.warn "Request timed out waiting response from #{routing_key}"\
                       ", correlation id #{correlation_id}, timeout #{timeout_in_seconds}s"

          @request_manager.delete(correlation_id)
          span.add_event('timeout')
          span.status = OpenTelemetry::Trace::Status.error("Timed out waiting response from #{routing_key}")
          span.finish
        end
      end
    end
  end
end
