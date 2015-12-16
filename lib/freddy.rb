require 'json'
require 'thread/pool'

require_relative 'freddy/adapters'
require_relative 'freddy/consumer'
require_relative 'freddy/producer'
require_relative 'freddy/request'
require_relative 'freddy/payload'
require_relative 'freddy/error_response'
require_relative 'freddy/invalid_request_error'
require_relative 'freddy/timeout_error'
require_relative 'freddy/utils'

class Freddy
  FREDDY_TOPIC_EXCHANGE_NAME = 'freddy-topic'.freeze

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
  #
  # @return [Freddy]
  #
  # @example
  #   Freddy.build(Logger.new(STDOUT), user: 'thumper', pass: 'howdy')
  def self.build(logger = Logger.new(STDOUT), config = {})
    connection = Adapters.determine.connect(config)

    new(connection, logger, config.fetch(:max_concurrency, 4))
  end

  attr_reader :channel, :consumer, :producer, :request

  def initialize(connection, logger, max_concurrency)
    @connection = connection
    @channel  = connection.create_channel
    @consume_thread_pool = Thread.pool(max_concurrency)
    @producer = Producer.new channel, logger
    @consumer = Consumer.new logger, @consume_thread_pool, @producer, @connection
    @request  = Request.new channel, logger, @producer, @consumer
  end
  private :initialize

  def respond_to(destination, &callback)
    @consumer.respond_to destination, &callback
  end

  def tap_into(pattern, &callback)
    @consumer.tap_into pattern, &callback
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
  #
  # @return [void]
  #
  # @example
  #   freddy.deliver 'Metrics', user_id: 5, metric: 'signed_in'
  def deliver(destination, payload, options = {})
    timeout = options.fetch(:timeout, 0)
    opts = {}
    opts[:expiration] = (timeout * 1000).to_i if timeout > 0

    @producer.produce destination, payload, opts
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

    @request.sync_request destination, payload, {
      timeout: timeout, delete_on_timeout: delete_on_timeout
    }
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
