require 'spec_helper'

describe Freddy::Consumer do
  let(:consumer) { described_class.new(logger, thread_pool, connection) }

  let(:connection) { Freddy::Adapters.determine.connect(config) }
  let(:thread_pool) { Thread.pool(1) }

  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  it "doesn't call passed block without any messages" do
    consumer.respond_to destination do
      @message_received = true
    end
    default_sleep

    expect(@message_received).to be_falsy
  end
end
