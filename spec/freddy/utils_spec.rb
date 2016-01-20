require 'spec_helper'

describe Freddy::Utils do
  describe '.format_exception' do
    subject { described_class.format_exception(exception) }

    let(:exception) { double(backtrace: backtrace, message: message) }
    let(:message)   { 'format exception test' }
    let(:backtrace) { ['line1', 'line2', 'line3'] }

    it 'format the exception' do
      should eq "format exception test\n" \
        "line1\n" \
        "line2\n" \
        'line3'
    end
  end

  describe '.notify' do
    subject { described_class.notify(error_class, error_message, parameters) }

    let(:env_attributes) { double }
    let(:error_class)    { double }
    let(:error_message)  { double }
    let(:parameters)     { double }

    context 'when Airbrake is defined' do
      let(:airbrake) { double }

      before do
        allow(ENV).to receive(:to_hash) { env_attributes }
        stub_const('::Airbrake', airbrake)
      end

      it 'notifies airbrake' do
        expect(airbrake).to receive(:notify_or_ignore).with(
          error_class: error_class,
          error_message: error_message,
          cgi_data: env_attributes,
          parameters: parameters
        )

        subject
      end
    end

    context 'when Airbrake is not defined' do
      it 'does nothing' do
        should eq(nil)
      end
    end
  end

  describe '.notify_exception' do
    subject { described_class.notify_exception(exception, {a: 'b'}) }

    let(:exception) { double }

    context 'when Airbrake is defined' do
      let(:airbrake) { double }

      before do
        stub_const('::Airbrake', airbrake)
      end

      it 'notifies airbrake' do
        expect(airbrake).to receive(:notify_or_ignore) do |ex, content|
          expect(ex).to eq(exception)
          expect(content[:cgi_data]).to be_instance_of(Hash)
          expect(content[:parameters]).to eq(a: 'b')
        end

        subject
      end
    end

    context 'when Airbrake is not defined' do
      it 'does nothing' do
        should eq(nil)
      end
    end
  end
end
