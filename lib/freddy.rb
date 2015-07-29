require 'bunny'
require 'json'
require 'symbolizer'

require_relative 'freddy/consumer'
require_relative 'freddy/producer'
require_relative 'freddy/request'

class Freddy
  class ErrorResponse < StandardError
    DEFAULT_ERROR_MESSAGE = 'Use #response to get the error response'

    attr_reader :response

    def initialize(response)
      @response = response
      super(format_message(response) || DEFAULT_ERROR_MESSAGE)
    end

    private

    def format_message(response)
      return unless response.is_a?(Hash)

      message = [response[:error], response[:message]].compact.join(': ')
      message.empty? ? nil : message
    end
  end

  class InvalidRequestError < ErrorResponse
  end

  class TimeoutError < ErrorResponse
  end

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

  def self.build(logger = Logger.new(STDOUT), bunny_config)
    bunny = Bunny.new(bunny_config)
    bunny.start

    channel = bunny.create_channel
    new(channel, logger)
  end

  attr_reader :channel, :consumer, :producer, :request

  def initialize(channel, logger)
    @channel  = channel
    @consumer = Consumer.new channel, logger
    @producer = Producer.new channel, logger
    @request  = Request.new channel, logger
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
end
