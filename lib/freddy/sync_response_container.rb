require 'thread'
require 'timeout'

class Freddy
  class SyncResponseContainer
    def initialize
      @mutex = Mutex.new
    end

    def call(response, delivery)
      @response = response
      @delivery = delivery
      @mutex.synchronize { @waiting.wakeup }
    end

    def on_timeout(&block)
      @on_timeout = block
    end

    def wait_for_response(timeout)
      @mutex.synchronize do
        @waiting = Thread.current
        @mutex.sleep(timeout)
      end

      if !defined?(@response)
        @on_timeout.call
        raise TimeoutError.new(
          error: 'RequestTimeout',
          message: 'Timed out waiting for response'
        )
      elsif @response.nil?
        raise StandardError, 'unexpected nil value for response'
      elsif !@delivery || @delivery.type == 'error'
        raise InvalidRequestError.new(@response)
      else
        @response
      end
    end
  end
end
