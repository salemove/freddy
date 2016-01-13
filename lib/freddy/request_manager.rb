class Freddy
  class RequestManager
    def initialize(logger)
      @requests = Hamster.mutable_hash
      @logger = logger
    end

    def no_route(correlation_id)
      if request = @requests[correlation_id]
        @requests.delete correlation_id
        request[:callback].call({error: 'Specified queue does not exist'}, nil)
      end
    end

    def store(correlation_id, opts)
      @requests.store(correlation_id, opts)
    end

    def delete(correlation_id)
      @requests.delete(correlation_id)
    end
  end
end
