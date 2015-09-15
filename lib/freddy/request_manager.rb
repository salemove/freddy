class Freddy
  class RequestManager

    def initialize(requests, logger)
      @requests, @logger = requests, logger
    end

    def start
      @timeout_thread = Thread.new do
        while true do
          clear_timeouts Time.now
          sleep 0.05
        end
      end
    end

    def no_route(correlation_id)
      if request = @requests[correlation_id]
        @requests.delete correlation_id
        request[:callback].call({error: 'Specified queue does not exist'}, nil)
      end
    end

    private

    def clear_timeouts(now)
      @requests.each do |key, value|
        timeout(key, value) if now > value[:timeout]
      end
    end

    def timeout(correlation_id, request)
      @requests.delete correlation_id

      @logger.warn "Request timed out waiting response from #{request[:destination]}, correlation id #{correlation_id}"
      Freddy.notify 'RequestTimeout', "Request timed out waiting for response from #{request[:destination]}", {
        correlation_id: correlation_id,
        destination: request[:destination],
        timeout: request[:timeout]
      }

      request[:callback].call({error: 'RequestTimeout', message: 'Timed out waiting for response'}, nil)
    end
  end
end
