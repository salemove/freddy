if RUBY_PLATFORM == 'java'
  require 'march_hare'
else
  require 'bunny'
end

require 'json'
require 'thread/pool'

require_relative 'freddy/adaptive_queue'
require_relative 'freddy/consumer'
require_relative 'freddy/producer'
require_relative 'freddy/request'
require_relative 'freddy/payload'
require_relative 'freddy/error_response'
require_relative 'freddy/invalid_request_error'
require_relative 'freddy/timeout_error'

class Freddy
  FREDDY_TOPIC_EXCHANGE_NAME = 'freddy-topic'.freeze

  def self.format_backtrace(backtrace)
    backtrace.map{ |x|
      x.match(/^(.+?):(\d+)(|:in `(.+)')$/);
      [$1,$2,$4]
    }.join "\n"
  end

  def self.format_exception(exception)
    "#{exception.exception}\n#{format_backtrace(exception.backtrace)}"
  end

  def self.notify(name, message, parameters={})
    if defined? Airbrake
      Airbrake.notify_or_ignore({
        error_class: name,
        error_message: message,
        cgi_data: ENV.to_hash,
        parameters: parameters
      })
    end
  end

  def self.notify_exception(exception, parameters={})
    if defined? Airbrake
      Airbrake.notify_or_ignore(exception, cgi_data: ENV.to_hash, parameters: parameters)
    end
  end

  def self.build(logger = Logger.new(STDOUT), config)
    if RUBY_PLATFORM == 'java'
      connection = MarchHare.connect(config)
    else
      connection = Bunny.new(config)
      connection.start
      connection
    end

    new(connection, logger, config.fetch(:max_concurrency, 4))
  end

  attr_reader :channel, :consumer, :producer, :request

  def initialize(connection, logger, max_concurrency)
    @connection = connection
    @channel  = connection.create_channel
    @consume_thread_pool = Thread.pool(max_concurrency)
    @consumer = Consumer.new channel, logger, @consume_thread_pool
    @producer = Producer.new channel, logger
    @request  = Request.new channel, logger, @producer, @consumer
  end

  def respond_to(destination, &callback)
    @request.respond_to destination, &callback
  end

  def tap_into(pattern, &callback)
    @consumer.tap_into pattern, &callback
  end

  def deliver(destination, payload, options = {})
    timeout = options.fetch(:timeout, 0)
    opts = {}
    opts[:expiration] = (timeout * 1000).to_i if timeout > 0

    @producer.produce destination, payload, opts
  end

  def deliver_with_response(destination, payload, options = {})
    timeout = options.fetch(:timeout, 3)
    delete_on_timeout = options.fetch(:delete_on_timeout, true)

    @request.sync_request destination, payload, {
      timeout: timeout, delete_on_timeout: delete_on_timeout
    }
  end

  def close
    @connection.close
  end
end
