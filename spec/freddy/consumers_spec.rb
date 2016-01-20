require 'spec_helper'

describe Freddy::Consumers do
  describe '.log_receive_event' do
    subject { described_class.log_receive_event(logger, queue_name, delivery) }

    let(:queue_name) { 'salemove' }
    let(:delivery) do
      instance_double(Freddy::Delivery,
        payload: {key: 'value'},
        correlation_id: 'a1b2'
      )
    end

    context 'when configured with logasm logger' do
      let(:logger) { logasm_class.new }
      let(:logasm_class) { Class.new }

      before do
        stub_const('::Logasm', logasm_class)
      end

      it 'logs the received event' do
        expect(logger).to receive(:debug).with('Received message',
          queue: 'salemove', payload: {key: 'value'}, correlation_id: 'a1b2'
        )

        subject
      end
    end

    context 'when configured with regular logger' do
      let(:logger) { Logger.new('/dev/null') }

      it 'logs the received event' do
        expect(logger).to receive(:debug)
          .with('Received message on salemove with payload {:key=>"value"} with correlation_id a1b2')

        subject
      end
    end
  end
end
