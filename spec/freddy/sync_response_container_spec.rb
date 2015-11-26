require 'spec_helper'

describe Freddy::SyncResponseContainer do
  let(:container) { described_class.new }

  context 'when timeout' do
    subject { container.wait_for_response(0.01) }

    it 'raises timeout error' do
      expect { subject }.to raise_error(Timeout::Error, 'execution expired')
    end
  end
end
