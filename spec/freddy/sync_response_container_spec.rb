require 'spec_helper'

describe Freddy::SyncResponseContainer do
  let(:container) { described_class.new }

  before do
    container.on_timeout {}
  end

  context 'when timeout' do
    subject { container.wait_for_response(0.01) }

    it 'raises timeout error' do
      expect { subject }.to raise_error do |error|
        expect(error).to be_a(Freddy::TimeoutError)
        expect(error.response).to eq(
          error: 'RequestTimeout',
          message: 'Timed out waiting for response'
        )
      end
    end
  end

  context 'when nil resonse' do
    let(:delivery) { {} }

    before do
      Thread.new do
        default_sleep
        container.call(nil, delivery)
      end
    end

    it 'raises timeout error' do
      expect {
        container.wait_for_response(2)
      }.to raise_error(StandardError, 'unexpected nil value for response')
    end
  end
end
