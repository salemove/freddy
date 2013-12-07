require 'spec_helper'
require 'salemove/messaging/messenger'
require_relative '../lib/messaging'

class Salemove::Messaging::Consumer
  def create_queue(queue_name)
    #want to auto_delete queues while testing
    @channel.queue(queue_name, auto_delete: true)
  end
end

class Salemove::Messaging::Request
  def create_response_queue
    #exclusive queues are deleted when the consumer disconnects,
    #auto_delete doesn't work when there are no requests
    @channel.queue("", exclusive: true, auto_delete: true)
  end
end

def random_destination
  SecureRandom.hex
end

def default_sleep
  sleep 0.01
end

def default_produce
  messenger.produce destination, payload
  default_sleep
end

def default_let
  let(:messenger) { Salemove::Messaging::Messenger.new }
  let(:consumer) { Salemove::Messaging::Consumer.new }
  let(:producer) { Salemove::Messaging::Producer.new }
  let(:destination) { random_destination }
  let(:payload) { {pay: 'load'} }
end

logger = Logger.new(STDOUT).tap { |l| l.level = Logger::ERROR }
Salemove::Messaging.setup(logger, host: 'localhost', port: 5672, user: 'guest', pass: 'guest')