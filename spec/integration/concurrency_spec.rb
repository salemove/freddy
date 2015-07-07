require 'spec_helper'

describe 'Concurrency' do
  let(:freddy) { Freddy.build(logger, config.merge(responder_thread_count: 1)) }

  it 'supports nested calls in #respond_to' do
    freddy.respond_to 'Concurrency1' do |payload, msg_handler|
      begin
        result = freddy.deliver_with_response 'Concurrency2', msg: 'noop'
        msg_handler.success(result)
      rescue Freddy::ErrorResponse => e
        msg_handler.error(e.response)
      end
    end

    freddy.respond_to 'Concurrency2' do |payload, msg_handler|
      begin
        result = freddy.deliver_with_response 'Concurrency3', msg: 'noop'
        msg_handler.success(result)
      rescue Freddy::ErrorResponse => e
        msg_handler.error(e.response)
      end
    end

    freddy.respond_to 'Concurrency3' do |payload, msg_handler|
      msg_handler.success({from: 'Concurrency3'})
    end

    result =
      begin
        freddy.deliver_with_response 'Concurrency1', msg: 'noop'
      rescue Freddy::ErrorResponse => e
        e.response
      end

    expect(result).to eq(from: 'Concurrency3')
  end

  it 'supports nested calls in #tap_into' do
    received1 = false
    received2 = false

    freddy.tap_into 'concurrency.*.queue1' do
      result = freddy.deliver_with_response 'TapConcurrency', msg: 'noop'
      expect(result).to eq(from: 'TapConcurrency')
      received1 = true
    end

    freddy.respond_to 'TapConcurrency' do |payload, msg_handler|
      msg_handler.success({from: 'TapConcurrency'})
      received2 = true
    end

    freddy.deliver 'concurrency.q.queue1', msg: 'noop'

    wait_for { received1 && received2 }

    expect(received1).to be(true)
    expect(received2).to be(true)
  end
end
