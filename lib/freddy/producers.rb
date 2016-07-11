class Freddy
  module Producers
    def self.log_send_event(logger, payload, destination)
      logger.debug message: 'Sending message', queue: destination, payload: payload
    end
  end
end

Dir[File.dirname(__FILE__) + '/producers/*.rb'].each(&method(:require))
