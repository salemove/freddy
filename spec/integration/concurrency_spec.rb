require 'spec_helper'

describe 'Concurrency' do
  let(:freddy1) { Freddy.build(logger, config) }
  let(:freddy2) { Freddy.build(logger, config) }
  let(:freddy3) { Freddy.build(logger, config) }

  after { [freddy1, freddy2, freddy3].each(&:close) }

  it 'supports multiple requests in #respond_to' do
    freddy1.respond_to 'Concurrency1' do |payload, msg_handler|
      begin
        freddy1.deliver_with_response 'Concurrency2', msg: 'noop'
        result2 = freddy1.deliver_with_response 'Concurrency3', msg: 'noop'
        msg_handler.success(result2)
      rescue Freddy::InvalidRequestError => e
        msg_handler.error(e.response)
      end
    end

    freddy2.respond_to 'Concurrency2' do |payload, msg_handler|
      begin
        msg_handler.success({from: 'Concurrency2'})
      rescue Freddy::InvalidRequestError => e
        msg_handler.error(e.response)
      end
    end

    freddy3.respond_to 'Concurrency3' do |payload, msg_handler|
      msg_handler.success({from: 'Concurrency3'})
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

    freddy2.respond_to 'TapConcurrency' do |payload, msg_handler|
      msg_handler.success({from: 'TapConcurrency'})
      received2 = true
    end

    freddy1.deliver 'concurrency.q.queue1', msg: 'noop'

    wait_for { received1 && received2 }

    expect(received1).to be(true)
    expect(received2).to be(true)
  end
end
