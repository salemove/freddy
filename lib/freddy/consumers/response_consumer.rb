# frozen_string_literal: true

class Freddy
  module Consumers
    class ResponseConsumer
      def initialize(logger)
        @logger = logger
      end

      def consume(_channel, queue, &)
        @logger.debug "Consuming messages on #{queue.name}"
        queue.subscribe(&)
      end
    end
  end
end
