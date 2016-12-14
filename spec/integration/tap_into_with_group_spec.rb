require 'spec_helper'
require 'hamster/experimental/mutable_set'

describe 'Tapping into with group identifier' do
  let(:deliverer) { Freddy.build(logger, config) }
  let(:responder1) { Freddy.build(logger, config) }
  let(:responder2) { Freddy.build(logger, config) }

  let(:destination)  { random_destination }

  after { [deliverer, responder1, responder2].each(&:close) }

  it 'receives a message once' do
    msg_counter = Hamster::MutableSet[]

    group_id = arbitrary_id
    responder1.tap_into(destination, group: group_id) {|msg| msg_counter << 'r1' }
    responder2.tap_into(destination, group: group_id) {|msg| msg_counter << 'r2' }
    deliverer.deliver(destination, {})

    default_sleep
    expect(msg_counter.count).to eq(1)
  end
end
