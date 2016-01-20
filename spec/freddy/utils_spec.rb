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
end
