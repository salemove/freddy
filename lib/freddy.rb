# frozen_string_literal: true

require 'json'
require 'concurrent'
require 'securerandom'
require 'opentelemetry'
require 'opentelemetry/semantic_conventions'
require_relative './freddy/version'

Dir["#{File.dirname(__FILE__)}/freddy/*.rb"].sort.each(&method(:require))

class Freddy
  FREDDY_TOPIC_EXCHANGE_NAME = 'freddy-topic'
  DEFAULT_MAX_CONCURRENCY = 4

  # Creates a new freddy instance
  #
  # @param [Logger] logger
  #   instance of a logger, defaults to the STDOUT logger
  # @param [Hash] config
  #   rabbitmq connection information
  # @option config [String] :host ('localhost')
  # @option config [Integer] :port (5672)
  # @option config [String] :user ('guest')
  # @option config [String] :pass ('guest')
  # @option config [Integer] :max_concurrency (4)
  #
  # @return [Freddy]
  #
  # @example
  #   Freddy.build(Logger.new($stdout), user: 'thumper', pass: 'howdy')
  def self.build(logger = Logger.new($stdout), max_concurrency: DEFAULT_MAX_CONCURRENCY, **config)
    connection = Adapters.determine.connect(config)
    new(connection, logger, max_concurrency)
  end

  # @private
  def self.tracer
    @tracer ||= OpenTelemetry.tracer_provider.tracer('freddy', Freddy::VERSION)
  end

  def initialize(connection, logger, max_concurrency)
    @connection = connection
    @logger = logger
    @prefetch_buffer_size = max_concurrency

    @send_and_forget_producer = Producers::SendAndForgetProducer.new(
      connection.create_channel, logger
    )
    @send_and_wait_response_producer = Producers::SendAndWaitResponseProducer.new(
      connection.create_channel, logger
    )
  end
  private :initialize

  # Listens and responds to messages
  #
  # This consumes messages on a given destination. It is useful for messages
  # that have to be processed once and then a result must be sent.
  #
  # @param [String] destination
  #   the queue name
  #
  # @yieldparam [Hash<Symbol => Object>] message
  #   Received message as a ruby hash with symbolized keys
  # @yieldparam [#success, #error] handler
  #   Handler for responding to messages. Use handler#success for successful
  #   response and handler#error for error response.
  #
  # @return [#shutdown]
  #
  # @example
  #   freddy.respond_to 'RegistrationService' do |attributes, handler|
  #     if id = register(attributes)
  #       handler.success(id: id)
  #     else
  #       handler.error(message: 'Can not do')
  #     end
  #   end
  def respond_to(destination, &callback)
    @logger.info "Listening for requests on #{destination}"

    channel = @connection.create_channel(prefetch: @prefetch_buffer_size)
    producer = Producers::ReplyProducer.new(channel, @logger)
    handler_adapter_factory = MessageHandlerAdapters::Factory.new(producer)

    Consumers::RespondToConsumer.consume(
      **{
        thread_pool: Concurrent::FixedThreadPool.new(@prefetch_buffer_size),
        destination: destination,
        channel: channel,
        handler_adapter_factory: handler_adapter_factory
      },
      &callback
    )
  end

  # Listens for messages without consuming them
  #
  # This listens for messages on a given destination or destinations without
  # consuming them. It is useful for general messages that two or more clients
  # are interested.
  #
  # @param [String] pattern_or_patterns
  #   the destination pattern. Use `#` wildcard for matching 0 or more words.
  #   Use `*` to match exactly one word.
  # @param [Hash] options
  # @option options [String] :group
  #   only one of the listeners in given group will receive a message. All
  #   listeners will receive a message if the group is not specified.
  # @option options [Boolean] :durable
  #   Should the consumer queue be durable? Default is `false`. This option can
  #   be used only in combination with option `:group`.
  # @option options [Boolean] :on_exception
  #   Defines consumer's behaviour when the callback fails to process a message
  #   and raises an exception. Can be one of `:ack`, `:reject` or `:requeue`.
  #   `:ack` simply acknowledges the message and re-raises the exception. `:reject`
  #   rejects the message without requeueing it. `:requeue` rejects the message with
  #   `requeue` flag.
  # @option options [String] :exchange_name
  #   Exchange to bind to. Default is `freddy-topic`.
  #
  # @yield [message] Yields received message to the block.
  # @yieldparam [Object] payload
  #   Yields the received message's payload.
  # @yieldparam [String] routing_key
  #   Yields the received message's routing key.
  # @yieldparam [Time] timestamp
  #   Yields received message's timestamp.
  #
  # @return [#shutdown]
  #
  # @example
  #   freddy.tap_into 'notifications.*' do |message|
  #     puts "Notification showed #{message.inspect}"
  #   end
  def tap_into(pattern_or_patterns, options = {}, &callback)
    @logger.debug "Tapping into messages that match #{pattern_or_patterns}"

    Consumers::TapIntoConsumer.consume(
      **{
        thread_pool: Concurrent::FixedThreadPool.new(@prefetch_buffer_size),
        patterns: Array(pattern_or_patterns),
        channel: @connection.create_channel(prefetch: @prefetch_buffer_size),
        options: options
      },
      &callback
    )
  end

  # Sends a message to given destination
  #
  # This is *send and forget* type of delivery. It sends a message to given
  # destination and does not wait for response. This is useful when there are
  # multiple consumers that are using #tap_into or you just do not care about
  # the response.
  #
  # @param [String] destination
  #   the queue name
  # @param [Hash] payload
  #   the payload that can be serialized to json
  # @param [Hash] options
  #   the options for delivery
  # @option options [Integer] :timeout (0)
  #   discards the message after given seconds if nobody consumes it. Message
  #   won't be discarded if timeout it set to 0 (default).
  # @option options [String] :compress (nil)
  #   - 'zlib' - compresses the payload with zlib
  # @return [void]
  #
  # @example
  #   freddy.deliver 'Metrics', user_id: 5, metric: 'signed_in'
  def deliver(destination, payload, options = {})
    timeout = options.fetch(:timeout, 0)
    compression_algorithm = options.fetch(:compress, nil)
    opts = {}
    opts[:expiration] = (timeout * 1000).to_i if timeout.positive?
    opts[:content_encoding] = compression_algorithm if compression_algorithm

    @send_and_forget_producer.produce(destination, payload, opts)
  end

  # Sends a message and waits for the response
  #
  # @param [String] destination
  #   the queue name
  # @param [Hash] payload
  #   the payload that can be serialized to json
  # @param [Hash] options
  #   the options for delivery
  # @option options [Integer] :timeout (3)
  #   throws a time out exception after given seconds when there is no response
  # @option options [Boolean] :delete_on_timeout (true)
  #   discards the message when timeout error is raised
  #
  # @raise [Freddy::TimeoutError]
  #   if nobody responded to the request
  # @raise [Freddy::InvalidRequestError]
  #   if the responder responded with an error response
  #
  # @return [Hash] the response
  #
  # @example
  #   begin
  #     response = freddy.deliver_with_response 'Users', type: 'fetch_all'
  #     puts "Got response #{response}"
  #   rescue Freddy::TimeoutError
  #     puts "Service unavailable"
  #   rescue Freddy::InvalidRequestError => e
  #     puts "Got error response: #{e.response}"
  #   end
  def deliver_with_response(destination, payload, options = {})
    timeout = options.fetch(:timeout, 3)
    delete_on_timeout = options.fetch(:delete_on_timeout, true)

    @send_and_wait_response_producer.produce destination, payload,
                                             timeout_in_seconds: timeout, delete_on_timeout: delete_on_timeout
  end

  # Closes the connection with message queue
  #
  # @return [void]
  #
  # @example
  #   freddy.close
  def close
    @connection.close
  end
end
