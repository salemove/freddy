require 'spec_helper'

describe Freddy::Traces::TraceId do
  describe '.generate' do
    it 'generates a trace id' do
      expect(described_class.generate).to_not be_nil
    end
  end
end
