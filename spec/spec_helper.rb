require 'rubygems'
require 'bundler'
Bundler.setup

require 'codeclimate-test-reporter'
SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       CodeClimate::TestReporter::Formatter
                                                     ])
  add_filter '/spec/'
end

require 'pry'
require 'freddy'
require 'logger'
require 'hamster/experimental/mutable_set'

Thread.abort_on_exception = true

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'

  config.before do
    OpenTracing.global_tracer ||= OpenTracing::Tracer.new
  end
end

def random_destination
  SecureRandom.hex
end

def arbitrary_id
  SecureRandom.hex
end

def default_sleep
  sleep 0.05
end

def wait_for
  100.times do
    return if yield
    sleep 0.005
  end
end

def deliver(custom_destination = destination)
  freddy.deliver custom_destination, payload
  default_sleep
end

def logger
  Logger.new(STDOUT).tap { |l| l.level = Logger::ERROR }
end

def config
  { host: 'localhost', port: 5672, user: 'guest', pass: 'guest' }
end

def spawn_echo_responder(freddy, queue_name)
  freddy.respond_to queue_name do |payload, msg_handler|
    msg_handler.success(payload)
  end
end

class ArrayLogger
  attr_accessor :calls

  def initialize
    @calls = []
  end

  def info(*args)
    @calls << args
  end
end
