require 'bunny'
require 'json'

module Salemove
  module Messaging

    def self.setup(logger=Logger.new(STDOUT), bunny_config)
      @bunny = Bunny.new bunny_config
      @bunny.start
      @logger = logger
      @channel = @bunny.create_channel
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

  end
end