require 'spec_helper'
require 'hamster/experimental/mutable_set'

describe 'Concurrency' do
  # rubocop:disable RSpec/IndexedLet
  let(:freddy1) { Freddy.build(logger, **config) }
  let(:freddy2) { Freddy.build(logger, **config) }
  let(:freddy3) { Freddy.build(logger, **config) }
  # rubocop:enable RSpec/IndexedLet

  after { [freddy1, freddy2, freddy3].each(&:close) }

  it 'supports multiple requests in #respond_to' do
    freddy1.respond_to 'Concurrency1' do |_payload, msg_handler|
      freddy1.deliver_with_response 'Concurrency2', msg: 'noop'
      result2 = freddy1.deliver_with_response 'Concurrency3', msg: 'noop'
      msg_handler.success(result2)
    rescue Freddy::InvalidRequestError => e
      msg_handler.error(e.response)
    end

    freddy2.respond_to 'Concurrency2' do |_payload, msg_handler|
      msg_handler.success(from: 'Concurrency2')
    rescue Freddy::InvalidRequestError => e
      msg_handler.error(e.response)
    end

    freddy3.respond_to 'Concurrency3' do |_payload, msg_handler|
      msg_handler.success(from: 'Concurrency3')
    end

    result =
      begin
        freddy1.deliver_with_response 'Concurrency1', msg: 'noop'
      rescue Freddy::InvalidRequestError => e
        e.response
      end

    expect(result).to eq(from: 'Concurrency3')
  end

  it 'supports nested calls in #tap_into' do
    received1 = false
    received2 = false

    freddy1.tap_into 'concurrency.*.queue1' do
      result = freddy1.deliver_with_response 'TapConcurrency', msg: 'noop'
      expect(result).to eq(from: 'TapConcurrency')
      received1 = true
    end

    freddy2.respond_to 'TapConcurrency' do |_payload, msg_handler|
      msg_handler.success(from: 'TapConcurrency')
      received2 = true
    end

    freddy1.deliver 'concurrency.q.queue1', msg: 'noop'

    wait_for { received1 && received2 }

    expect(received1).to be(true)
    expect(received2).to be(true)
  end

  it 'supports adding multiple #tap_into listeners' do
    results = 10.times.map do |id|
      Thread.new do
        freddy1.tap_into "tap_into.listener.#{id}" do
        end
      end
    end.map(&:join)

    expect(results.count).to eq(10)
  end

  it 'supports adding multiple #respond_to listeners' do
    results = 10.times.map do |id|
      Thread.new do
        freddy1.respond_to "respond_to.listener.#{id}" do
        end
      end
    end.map(&:join)

    expect(results.count).to eq(10)
  end

  context 'with concurrent executions of deliver_with_response' do
    let(:nr_of_threads) { 50 }
    let(:payload) { { pay: 'load' } }
    let(:msg_counter) { Hamster::MutableSet[] }
    let(:queue_name) { random_destination }

    before do
      spawn_echo_responder(freddy1, queue_name)
    end

    it 'is supported' do
      nr_of_threads.times.map do |index|
        Thread.new do
          response = freddy1.deliver_with_response(queue_name, payload)
          msg_counter << index
          expect(response).to eq(payload)
        end
      end.each(&:join)
      expect(msg_counter.count).to eq(nr_of_threads)
    end
  end
end
