module Messaging
  class SyncResponseContainer
    def call(response, _msg_handler)
      @response = response
    end

    def wait_for_response
      sleep 0.0001 until filled?
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
