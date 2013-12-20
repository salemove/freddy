require 'spec_helper'
require 'freddy'

class Messaging::Consumer
  def create_queue(queue_name)
    #want to auto_delete queues while testing
    @channel.queue(queue_name, auto_delete: true)
  end
end

def random_destination
  SecureRandom.hex
end

def default_sleep
  sleep 0.05
end

def deliver(custom_destination = destination)
  freddy.deliver custom_destination, payload
  default_sleep
end

def default_let
  let(:freddy) { Freddy.new }
  let(:consumer) { Messaging::Consumer.new }
  let(:producer) { Messaging::Producer.new }
  let(:destination) { random_destination }
  let(:payload) { {pay: 'load'} }
end

logger = Logger.new(STDOUT).tap { |l| l.level = Logger::ERROR }
Freddy.setup(logger, host: 'localhost', port: 5672, user: 'guest', pass: 'guest')