require 'spec_helper'

describe Freddy::MessageHandler do
  subject(:handler) { described_class.new(adapter, delivery) }

  let(:adapter) { double }
  let(:delivery) { double }

  describe '#success' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:success).with(delivery, x: 'y')

      subject.success(x: 'y')
    end
  end

  describe '#error' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:error).with(delivery, error: 'text')

      subject.error(error: 'text')
    end
  end
end
