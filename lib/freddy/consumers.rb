class Freddy
  module Consumers
    def self.log_receive_event(logger, queue_name, delivery)
      if defined?(Logasm) && logger.is_a?(Logasm)
        logger.debug "Received message", queue: queue_name, payload: delivery.payload, correlation_id: delivery.correlation_id
      else
        logger.debug "Received message on #{queue_name} with payload #{delivery.payload} with correlation_id #{delivery.correlation_id}"
      end
    end
  end
end

Dir[File.dirname(__FILE__) + '/consumers/*.rb'].each(&method(:require))
