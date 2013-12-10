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
    @consumer, @producer, @request = Messaging::Consumer.new(@channel, @logger), Messaging::Producer.new(@channel, @logger), Messaging::Request.new(@channel, @logger)
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

  def initialize(use_distinct_connection = false, logger = Freddy.logger)
    @logger = logger
    if use_distinct_connection
      @channel = Freddy.new_channel
      @consumer, @producer, @request = Messaging::Consumer.new(@channel, @logger), Messaging::Producer.new(@channel, @logger), Messaging::Request.new(@channel, @logger)
    else 
      @consumer, @producer, @request, @channel =Freddy.consumer, Freddy.producer, Freddy.request, Freddy.channel
    end
  end

  def respond_to(destination, block_thread = false, &block)
    @request.respond_to destination, block_thread, &block
  end

  def deliver(destination, payload)
    @producer.produce destination, payload
  end

  def deliver_with_ack(destination, payload, timeout_seconds = 3, &block)
    @producer.produce_with_ack destination, payload, timeout_seconds, &block
  end

  def deliver_with_response(destination, payload, timeout_seconds = 3,&block)
    @request.request destination, payload, timeout_seconds, &block
  end

  private 

end
