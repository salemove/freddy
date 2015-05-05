require 'bunny'
require 'json'
require 'symbolizer'

require_relative 'freddy/consumer'
require_relative 'freddy/producer'
require_relative 'freddy/request'

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

  def self.build(logger = Logger.new(STDOUT), bunny_config)
    bunny = Bunny.new(bunny_config)
    bunny.start

    channel = bunny.create_channel(nil, bunny_config[:responder_thread_count] || 4)
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

  def deliver(destination, payload, timeout: 3, delete_on_timeout: true)
    @producer.produce destination, payload, {
      timeout: timeout, delete_on_timeout: delete_on_timeout
    }
  end

  def deliver_with_ack(destination, payload, timeout: 3, delete_on_timeout: true, &callback)
    @producer.produce_with_ack destination, payload, {
      timeout: timeout, delete_on_timeout: delete_on_timeout
    }, &callback
  end

  def deliver_with_response(destination, payload, timeout: 3, delete_on_timeout: true, &callback)
    opts = {timeout: timeout, delete_on_timeout: delete_on_timeout}

    if block_given?
      @request.async_request destination, payload, opts, &callback
    else
      @request.sync_request destination, payload, opts
    end
  end

  def tap_into(pattern, &callback)
    @consumer.tap_into pattern, &callback
  end
end
