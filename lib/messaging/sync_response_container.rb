require 'timeout'

module Messaging
  class SyncResponseContainer
    def call(response, _msg_handler)
      @response = response
    end

    def wait_for_response(timeout)
      Timeout::timeout(timeout) do
        sleep 0.001 until filled?
      end
      @response
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
