class Freddy
  class RequestTimeoutClearer

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

    def force_timeout(correlation_id)
      if request = @requests[correlation_id]
        timeout(correlation_id, request)
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

      message = "Request #{correlation_id} timed out waiting response from #{request[:destination]} with timeout #{request[:timeout]}"
      @logger.warn message
      Freddy.notify 'RequestTimeout', message, request: correlation_id, destination: request[:destination], timeout: request[:timeout]
      request[:callback].call({error: 'Timed out waiting for response'}, nil)
    end
  end
end
