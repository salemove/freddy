module Messaging
 class RequestTimeoutClearer

    def initialize(requests, logger)
      @requests, @logger = requests, logger
      initialize_timeout_clearer_thread
    end

    def initialize_timeout_clearer_thread
      @timeout_thread = Thread.new do
        while true do
          clear_timeouts Time.now
          sleep 0.05
        end
      end
    end

    def clear_timeouts(now)
      @requests.each do |key, value|
        if now > value[:timeout]
          message = "Request #{key} timed out waiting response from #{value[:destination]} with timeout #{value[:timeout]}"
          @logger.warn message
          Freddy.notify 'RequestTimeout', message, request: key, destination: value[:destination], timeout: value[:timeout]
          value[:callback].call({error: 'Timed out waiting for response'}, nil)
          @requests.delete key
        end
      end
    end
  end
end
