require 'spec_helper'

describe Freddy::MessageHandler do
  subject(:handler) { described_class.new(adapter, delivery) }

  let(:adapter) { double }
  let(:delivery) { double(properties: properties) }
  let(:properties) { {reply_to: reply_to} }

  let(:reply_to) { double }

  describe '#ack' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:ack).with(reply_to, x: 'y')

      subject.ack(x: 'y')
    end
  end

  describe '#nack' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:nack).with(reply_to, error: 'text')

      subject.nack(error: 'text')
    end
  end
end
