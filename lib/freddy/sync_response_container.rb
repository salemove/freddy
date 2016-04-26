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
      if response.nil?
        raise StandardError, 'unexpected nil value for response'
      end

      @response = response
      @delivery = delivery
      @mutex.synchronize { @resource.signal }
    end

    def wait_for_response(timeout)
      @mutex.synchronize { @response || @resource.wait(@mutex, timeout) }

      if !@response
        @on_timeout.call
        raise TimeoutError.new(
          error: 'RequestTimeout',
          message: 'Timed out waiting for response'
        )
      elsif !@delivery || @delivery.type == 'error'
        raise InvalidRequestError.new(@response)
      else
        @response
      end
    end
  end
end
