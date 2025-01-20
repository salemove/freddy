require 'spec_helper'
require 'hamster/experimental/mutable_set'

describe 'Tapping into with group identifier' do
  let(:deliverer) { Freddy.build(logger, **config) }

  # rubocop:disable RSpec/IndexedLet
  let(:responder1) { Freddy.build(logger, **config) }
  let(:responder2) { Freddy.build(logger, **config) }
  # rubocop:enable RSpec/IndexedLet

  let(:destination) { random_destination }

  after { [deliverer, responder1, responder2].each(&:close) }

  it 'raises an exception if option :durable is provided without group' do
    expect { responder1.tap_into(destination, durable: true) }
      .to raise_error(RuntimeError)
  end

  it 'receives a message once' do
    msg_counter = Hamster::MutableSet[]

    group_id = arbitrary_id
    responder1.tap_into(destination, group: group_id) { |_msg| msg_counter << 'r1' }
    responder2.tap_into(destination, group: group_id) { |_msg| msg_counter << 'r2' }
    deliverer.deliver(destination, {})

    default_sleep
    expect(msg_counter.count).to eq(1)
  end

  it 'can requeue message on exception' do
    counter = 0

    responder1.tap_into(destination, group: arbitrary_id, on_exception: :requeue) do
      counter += 1
      raise 'error' if counter == 1
    end

    deliverer.deliver(destination, {})

    wait_for { counter == 2 }
    expect(counter).to eq(2)
  end

  it 'taps into multiple topics' do
    destination2 = random_destination
    counter = 0

    responder1.tap_into([destination, destination2], group: arbitrary_id) do
      counter += 1
    end

    deliverer.deliver(destination, {})
    deliverer.deliver(destination2, {})

    wait_for { counter == 2 }
    expect(counter).to eq(2)
  end
end
