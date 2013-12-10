require 'messaging/consumer'
require 'messaging/producer'
require 'messaging/request'
require 'bunny'
require 'json'

class Freddy

  def self.setup(logger=Logger.new(STDOUT), bunny_config)
    @bunny = Bunny.new bunny_config
    @bunny.start
    @logger = logger
    @channel = @bunny.create_channel
    @consumer = Messaging::Consumer.new @channel, @logger
    @producer = Messaging::Producer.new @channel, @logger
    @request = Messaging::Request.new @channel, @logger
  end

  def self.channel
    @channel
  end

  def self.new_channel
    @bunny.create_channel
  end

  def self.logger
    @logger
  end

  def self.consumer
    @consumer
  end

  def self.producer
    @producer
  end

  def self.request
    @request
  end

  def self.symbolize_keys(hash)
    hash.inject({}) do |result, (key, value)|
      new_key = case key
                when String then key.to_sym
                else key
                end
      new_value = case value
                  when Hash then symbolize_keys(value)
                  else value
                  end
      result[new_key] = new_value
      result
    end
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
    @request.request destination, payload, timeout_seconds, &callback
  end

  private 

end
