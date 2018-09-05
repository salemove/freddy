# frozen_string_literal: true

class Freddy
  class RequestManager
    def initialize(logger)
      @requests = ConcurrentHash.new
      @logger = logger
    end

    def no_route(correlation_id)
      request = @requests[correlation_id]
      return unless request

      delete(correlation_id)
      request[:callback].call({ error: 'Specified queue does not exist' }, nil)
    end

    def store(correlation_id, opts)
      @requests[correlation_id] = opts
    end

    def delete(correlation_id)
      @requests.delete(correlation_id)
    end

    class ConcurrentHash < Hash
      # CRuby hash does not need any locks. Only adding when using JRuby.
      if RUBY_PLATFORM == 'java'
        require 'jruby/synchronized'
        include JRuby::Synchronized
      end
    end
  end
end
