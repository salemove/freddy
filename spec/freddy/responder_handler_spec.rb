require 'spec_helper'

describe Freddy::ResponderHandler do
  let(:freddy) { Freddy.build(logger, **config) }

  let(:destination) { random_destination }
  let(:payload)     { { pay: 'load' } }

  after { freddy.close }

  describe '#shutdown' do
    it 'lets ongoing workers to finish' do
      count = 0

      consumer_handler = freddy.respond_to destination do
        sleep 0.3
        count += 1
      end
      deliver

      sleep 0.15
      consumer_handler.shutdown

      expect(count).to eq(1)
    end

    it 'does not accept new jobs' do
      count = 0

      consumer_handler = freddy.respond_to destination do
        count += 1
      end

      consumer_handler.shutdown
      deliver

      expect(count).to eq(0)
    end

    it 'does not touch other handlers' do
      count = 0

      freddy.respond_to destination do
        count += 1
      end

      consumer_handler2 = freddy.respond_to random_destination do
        count += 1
      end
      consumer_handler2.shutdown

      deliver
      expect(count).to eq(1)
    end
  end
end
