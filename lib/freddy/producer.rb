require_relative 'producers/send_and_forget_producer'
require_relative 'producers/send_and_wait_response_producer'
require 'json'

class Freddy
  class Producer
    def initialize(logger, connection)
      @logger = logger
      @connection = connection
      @send_and_forget_producer = Producers::SendAndForgetProducer.new(
        connection.create_channel, logger
      )
      @send_and_wait_response_producer = Producers::SendAndWaitResponseProducer.new(
        connection.create_channel, logger
      )
    end

    def produce(destination, payload, properties = {})
      @send_and_forget_producer.produce(destination, payload, properties)
    end

    def produce_and_wait_response(destination, payload, properties = {})
      @send_and_wait_response_producer.produce(destination, payload, properties)
    end
  end
end
