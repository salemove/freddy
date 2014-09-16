require_relative 'messaging/consumer'
require_relative 'messaging/producer'
require_relative 'messaging/request'
require 'bunny'
require 'json'
require 'symbolizer'

class Freddy

  FREDDY_TOPIC_EXCHANGE_NAME = 'freddy-topic'.freeze

  class << self
    attr_reader :logger, :consumer, :producer, :request, :channel
  end

  def self.setup(logger = Logger.new(STDOUT), bunny_config)
    @bunny = Bunny.new bunny_config
    @bunny.start
    @logger = logger
    @channel = @bunny.create_channel(nil, bunny_config[:responder_thread_count] || 4)
    @consumer = Messaging::Consumer.new @channel, @logger
    @producer = Messaging::Producer.new @channel, @logger
    @request = Messaging::Request.new @channel, @logger
  end

  def self.new_channel
    @bunny.create_channel
  end

  def self.format_backtrace(backtrace)
    backtrace.map{ |x|
      x.match(/^(.+?):(\d+)(|:in `(.+)')$/);
      [$1,$2,$4]
    }.join "\n"
  end

  def self.format_exception(exception)
    "#{exception.exception}\n#{format_backtrace(exception.backtrace)}"
  end

  def initialize(logger = Freddy.logger)
    @logger = logger
    @consumer, @producer, @request, @channel = Freddy.consumer, Freddy.producer, Freddy.request, Freddy.channel
  end

  def use_distinct_connection
    @channel = Freddy.new_channel
    @consumer = Messaging::Consumer.new @channel, @logger
    @producer = Messaging::Producer.new @channel, @logger
    @request = Messaging::Request.new @channel, @logger
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
