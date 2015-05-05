require 'spec_helper'

describe Freddy::Consumer do
  default_let

  let(:consumer) { freddy.consumer }

  it 'raises exception when no consumer is provided' do
    expect { consumer.consume destination }.to raise_error described_class::EmptyConsumer
  end

  it "doesn't call passed block without any messages" do
    consumer.consume destination do
      @message_received = true
    end
    expect(@message_received).not_to be true
    deliver
  end
end
