require 'thread'
require 'timeout'

class Freddy
  class SyncResponseContainer
    def initialize(on_timeout)
      @mutex = Mutex.new
      @resource = ConditionVariable.new
      @on_timeout = on_timeout
    end

    def call(response, delivery)
      @mutex.synchronize do
        @response = response
        @delivery = delivery
        @resource.signal
      end
    end

    def wait_for_response(timeout)
      @mutex.synchronize do
        @resource.wait(@mutex, timeout) unless response_received?
      end

      if !response_received?
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

    private

    def response_received?
      defined?(@response)
    end
  end
end
