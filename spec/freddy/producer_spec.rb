require 'spec_helper'

describe Freddy::Producer do

  default_let

  let(:producer) { freddy.producer }

  describe 'with messages that need to be acknowledged' do
    it 'raises error if no handler is provided' do
      expect { producer.produce_with_ack destination, payload, timeout: 3 }.to raise_error described_class::EmptyAckHandler
    end
  end

end
