# frozen_string_literal: true

class Freddy
  class RequestManager
    def initialize(logger)
      @requests = {}
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
  end
end
