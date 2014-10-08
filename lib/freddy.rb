require 'bunny'
require 'json'
require 'symbolizer'

require_relative 'messaging/consumer'
require_relative 'messaging/producer'
require_relative 'messaging/request'

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

  attr_reader :consumer, :producer, :request

  def initialize(channel, logger)
    @consumer = Messaging::Consumer.new channel, logger
    @producer = Messaging::Producer.new channel, logger
    @request  = Messaging::Request.new channel, logger
  end

  def respond_to(destination, &callback)
    @request.respond_to destination, false, &callback
  end

  def respond_to_and_block(destination, &callback)
    @request.respond_to destination, true, &callback
  end

  def deliver(destination, payload)
    @producer.produce destination, payload
  end

  def deliver_with_ack(destination, payload, timeout_seconds = 3, &callback)
    @producer.produce_with_ack destination, payload, timeout_seconds, &callback
  end

  def deliver_with_response(destination, payload, timeout_seconds = 3,&callback)
    if block_given?
      @request.async_request destination, payload, timeout_seconds, &callback
    else
      @request.sync_request destination, payload, timeout_seconds
    end
  end

  def tap_into(pattern, &callback)
    @consumer.tap_into pattern, {block: false}, &callback
  end

  def tap_into_and_block(pattern, &callback)
    @consumer.tap_into pattern, {block: true}, &callback
  end

end
