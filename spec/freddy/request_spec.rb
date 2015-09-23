#Thread.abort_on_exception = true
require 'spec_helper'

describe Freddy::Request do
  let(:freddy) { Freddy.build(logger, config) }

  let(:destination) { random_destination }
  let(:payload)     { {pay: 'load'} }

  let(:request) { freddy.request }

  it 'raises empty responder exception when responding without callback' do
    expect {@responder = request.respond_to destination }.to raise_error described_class::EmptyResponder
  end

  context 'requesting from multiple threads' do
    let(:nr_of_threads) { 50 }

    before do
      freddy.respond_to 'thread-queue' do |payload, msg_handler|
        puts "RESPONDING"
        msg_handler.success(payload)
      end
    end

    it 'handles multiple threads', focus: true do
      require 'hamster/experimental/mutable_set'
      msg_counter = Hamster.mutable_set
      nr_of_threads.times.map do |index|
        Thread.new do
          response = freddy.deliver_with_response 'thread-queue', payload
          msg_counter << index
          expect(response).to eq(payload)
        end
      end.each(&:join)
      expect(msg_counter.count).to eq(nr_of_threads)
    end

  end

end
