require 'spec_helper'

describe Freddy::TraceCarrier do
  subject(:carrier) { described_class.new(properties) }

  context 'when adding trace information' do
    let(:properties) { {x: 'y'} }
    let(:key_name) { 'some-key' }
    let(:key_value) { 'some-key' }

    it 'adds a header with x-trace- prefix' do
      carrier[key_name] = key_value
      expect(properties[:headers]["x-trace-#{key_name}"]).to eq(key_value)
    end
  end

  context 'when extracting trace information' do
    let(:key_name) { 'some-key' }
    let(:serialized_key_name) { "x-trace-#{key_name}" }
    let(:key_value) { 'some-key' }

    let(:properties) do
      double(headers: {serialized_key_name => key_value})
    end

    it 'extracts a header with x-trace- prefix' do
      expect(carrier[key_name]).to eq(key_value)
    end
  end

  describe '#each' do
    context 'when headers are present' do
      let(:properties) do
        double(
          headers: {
            "x-trace-key1" => "value1",
            "x-trace-key2" => "value2",
            "other-key" => "value3"
          }
        )
      end

      it 'iterates over keys starting with x-trace- prefix' do
        expect(carrier.each.count).to eq(2)
      end
    end

    context 'when no headers' do
      let(:properties) { double(headers: nil) }

      it 'iterates over an empty list' do
        expect(carrier.each.count).to eq(0)
      end
    end
  end
end
