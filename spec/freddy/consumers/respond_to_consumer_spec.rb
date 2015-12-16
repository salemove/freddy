require 'spec_helper'

describe Freddy::Consumers::RespondToConsumer do
  let(:consumer) { described_class.new(thread_pool, logger) }

  let(:connection)  { Freddy::Adapters.determine.connect(config) }
  let(:thread_pool) { Thread.pool(1) }
  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  after do
    connection.close
  end

  it "doesn't call passed block without any messages" do
    consumer.consume destination, connection.create_channel do
      @message_received = true
    end
    default_sleep

    expect(@message_received).to be_falsy
  end
end
