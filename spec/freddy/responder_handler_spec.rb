require 'spec_helper'

describe Freddy::ResponderHandler do
  let(:freddy) { Freddy.build(logger, config) }

  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  after { freddy.close }

  it 'can cancel listening for messages' do
    consumer_handler = freddy.respond_to destination do
      @messages_count ||= 0
      @messages_count += 1
    end
    deliver
    consumer_handler.cancel
    deliver

    expect(@messages_count).to eq 1
  end
end
