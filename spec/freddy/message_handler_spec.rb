require 'spec_helper'

describe Freddy::MessageHandler do
  subject(:handler) { described_class.new(adapter, delivery) }

  let(:adapter) { double }
  let(:delivery) { double(reply_to: reply_to, correlation_id: 'abc') }
  let(:reply_to) { double }

  describe '#success' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:success).with(reply_to, x: 'y')

      subject.success(x: 'y')
    end
  end

  describe '#error' do
    it 'delegates to the adapter' do
      expect(adapter).to receive(:error).with(reply_to, error: 'text')

      subject.error(error: 'text')
    end
  end
end
