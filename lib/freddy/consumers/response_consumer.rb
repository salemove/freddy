class Freddy
  module Consumers
    class ResponseConsumer
      def initialize(logger)
        @logger = logger
      end

      def consume(channel, queue, &block)
        @logger.debug "Consuming messages on #{queue.name}"
        queue.subscribe do |delivery|
          block.call(delivery)
        end
      end
    end
  end
end
