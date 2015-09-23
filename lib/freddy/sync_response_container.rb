require 'timeout'

class Freddy
  class SyncResponseContainer
    def call(response, delivery)
      @response = response
      @delivery = delivery
    end

    def wait_for_response(timeout)
      Timeout::timeout(timeout) do
        sleep 0.001 until filled?
      end

      if @response[:error] == 'RequestTimeout'
        raise TimeoutError.new(@response)
      elsif !@delivery || @delivery.metadata.type == 'error'
        raise InvalidRequestError.new(@response)
      else
        @response
      end
    end

    private

    def to_proc
      Proc.new {|*args| self.call(*args)}
    end

    def filled?
      !@response.nil?
    end
  end
end
