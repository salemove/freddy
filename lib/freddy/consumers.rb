class Freddy
  module Consumers
    def self.log_receive_event(logger, queue_name, delivery)
      logger.debug(
        message: 'Received message',
        queue: queue_name,
        payload: delivery.payload,
        correlation_id: delivery.correlation_id,
        trace: Freddy.trace.to_h
      )
    end
  end
end

Dir[File.dirname(__FILE__) + '/consumers/*.rb'].each(&method(:require))
