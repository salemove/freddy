require 'spec_helper'

describe Freddy::Consumer do
  let(:freddy) { Freddy.build(logger, config) }

  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  let(:consumer) { freddy.consumer }

  it 'raises exception when no consumer is provided' do
    expect { consumer.consume destination }.to raise_error described_class::EmptyConsumer
  end

  it "doesn't call passed block without any messages" do
    consumer.consume destination do
      @message_received = true
    end
    default_sleep

    expect(@message_received).to be_falsy
  end
end
