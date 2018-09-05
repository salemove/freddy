require 'spec_helper'

describe Freddy::Payload do
  describe '#dump' do
    it 'serializes time objects as iso8601 format strings' do
      expect(dump(time: Time.utc(2016, 1, 4, 20, 18)))
        .to eq('{"time":"2016-01-04T20:18:00Z"}')
    end

    it 'serializes time objects in an array as iso8601 format strings' do
      expect(dump(time: [Time.utc(2016, 1, 4, 20, 18)]))
        .to eq('{"time":["2016-01-04T20:18:00Z"]}')
    end

    it 'serializes time objects in a nested hash as iso8601 format strings' do
      expect(dump(x: { time: Time.utc(2016, 1, 4, 20, 18) }))
        .to eq('{"x":{"time":"2016-01-04T20:18:00Z"}}')
    end

    it 'serializes date objects as iso8601 format strings' do
      expect(dump(date: Date.new(2016, 1, 4)))
        .to eq('{"date":"2016-01-04"}')
    end

    it 'serializes date objects in an array as iso8601 format strings' do
      expect(dump(date: [Date.new(2016, 1, 4)]))
        .to eq('{"date":["2016-01-04"]}')
    end

    it 'serializes date objects in a nested hash as iso8601 format strings' do
      expect(dump(x: { date: Date.new(2016, 1, 4) }))
        .to eq('{"x":{"date":"2016-01-04"}}')
    end

    it 'serializes datetime objects as iso8601 format strings' do
      expect(dump(datetime: DateTime.new(2016, 1, 4, 20, 18))) # rubocop:disable Style/DateTime
        .to eq('{"datetime":"2016-01-04T20:18:00+00:00"}')
    end

    it 'serializes datetime objects in an array as iso8601 format strings' do
      expect(dump(datetime: [DateTime.new(2016, 1, 4, 20, 18)])) # rubocop:disable Style/DateTime
        .to eq('{"datetime":["2016-01-04T20:18:00+00:00"]}')
    end

    it 'serializes datetime objects in a nested hash as iso8601 format strings' do
      expect(dump(x: { datetime: DateTime.new(2016, 1, 4, 20, 18) })) # rubocop:disable Style/DateTime
        .to eq('{"x":{"datetime":"2016-01-04T20:18:00+00:00"}}')
    end

    def dump(payload)
      described_class.dump(payload)
    end
  end
end
