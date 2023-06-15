require 'spec_helper'

describe 'Tapping into with exchange identifier' do
  let(:freddy) { Freddy.build(logger, **config) }

  let(:connection) { Freddy::Adapters.determine.connect(config) }
  let(:topic) { 'test_topic_exchange' }
  let(:channel) { connection.create_channel }
  let(:message_payload) { { test: 'test' }.to_json }
  let(:expected_payload) { { test: 'test' } }
  let(:publish_timestamp) { Time.now.to_i }

  after do
    connection.close
    freddy.close
  end

  it 'receives message' do
    freddy.tap_into('pattern.*', exchange_name: topic) do |payload, _routing_key, timestamp|
      @received_payload = payload
      @received_timestamp = timestamp
    end

    channel.topic(topic).publish(message_payload, { routing_key: 'pattern.random', timestamp: publish_timestamp })

    wait_for { @received_payload }
    wait_for { @received_timestamp }

    expect(@received_payload).to eq(expected_payload)
    expect(@received_timestamp.to_i).to eq(publish_timestamp)
  end

  it 'receives message with nil timestamp when timestamp is not published' do
    received_timestamp = 0
    freddy.tap_into('pattern.*', exchange_name: topic) do |_payload, _routing_key, timestamp|
      received_timestamp = timestamp
    end

    channel.topic(topic).publish(message_payload, { routing_key: 'pattern.random' })
    default_sleep

    expect(received_timestamp).to eq(nil)
  end
end
