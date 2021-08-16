require 'spec_helper'

describe Freddy::ErrorResponse do
  subject(:error) { described_class.new(input) }

  context 'with an error type' do
    let(:input) { { error: 'SomeError' } }

    describe '#response' do
      subject { error.response }

      it { is_expected.to eq(input) }
    end

    describe '#message' do
      subject(:message) { error.message }

      it 'uses error type as a message' do
        expect(message).to eq('SomeError')
      end
    end
  end

  context 'with an error type and message' do
    let(:input) { { error: 'SomeError', message: 'extra info' } }

    describe '#response' do
      subject { error.response }

      it { is_expected.to eq(input) }
    end

    describe '#message' do
      subject(:message) { error.message }

      it 'uses error type as a message' do
        expect(message).to eq('SomeError: extra info')
      end
    end
  end

  context 'without an error type' do
    let(:input) { { something: 'else' } }

    describe '#response' do
      subject { error.response }

      it { is_expected.to eq(input) }
    end

    describe '#message' do
      subject(:message) { error.message }

      it 'uses default error message as a message' do
        expect(message).to eq('Use #response to get the error response')
      end
    end
  end
end
