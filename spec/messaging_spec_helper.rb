require 'spec_helper'
require 'salemove/messaging/consumer'
require 'salemove/messaging/producer'
require_relative '../lib/messaging'

class Salemove::Messaging::Consumer
  def create_queue(queue_name)
    #want to make the queues auto_delete
    @channel.queue(queue_name, auto_delete: true)
  end
end

def random_destination
  SecureRandom.hex
end

def default_sleep
  sleep 0.1
end

def default_consume(&block)
  consumer.consume destination do |payload, ops|
    @message_received = true
    @received_payload = payload
    @messages_count ||= 0
    @messages_count += 1
    block.call payload, ops if block
  end
end

def default_produce
  producer.produce destination, payload
  default_sleep
end

def default_produce_with_ack(&block)
  producer.produce_with_ack destination, payload do |error|
    @ack_error = error
    block.call error if block
  end
  default_sleep
end

def default_let
  let(:consumer) { Salemove::Messaging::Consumer.new }
  let(:destination) { random_destination }
  let(:producer) { Salemove::Messaging::Producer.new }
  let(:payload) { {pay: 'load'} }
end

logger = Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
Salemove::Messaging.setup(logger, host: 'localhost', port: 5672, user: 'guest', pass: 'guest')