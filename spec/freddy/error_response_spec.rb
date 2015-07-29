require 'spec_helper'

describe Freddy::ErrorResponse do
  subject(:error) { described_class.new(input) }

  context 'with an error type' do
    let(:input) { {error: 'SomeError'} }

    describe '#response' do
      subject { error.response }

      it { should eq(input) }
    end

    describe '#message' do
      subject { error.message }

      it 'uses error type as a message' do
        should eq('SomeError')
      end
    end
  end

  context 'with an error type and message' do
    let(:input) { {error: 'SomeError', message: 'extra info'} }

    describe '#response' do
      subject { error.response }

      it { should eq(input) }
    end

    describe '#message' do
      subject { error.message }

      it 'uses error type as a message' do
        should eq('SomeError: extra info')
      end
    end
  end

  context 'without an error type' do
    let(:input) { {something: 'else'} }

    describe '#response' do
      subject { error.response }

      it { should eq(input) }
    end

    describe '#message' do
      subject { error.message }

      it 'uses default error message as a message' do
        should eq('Use #response to get the error response')
      end
    end
  end
end
