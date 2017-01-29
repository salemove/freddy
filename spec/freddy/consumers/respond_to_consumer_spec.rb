require 'spec_helper'

describe Freddy::Consumers::RespondToConsumer do
  let(:consumer) do
    described_class.new(
      logger: logger,
      thread_pool: thread_pool,
      destination: destination,
      channel: channel,
      handler_adapter_factory: msg_handler_adapter_factory
    )
  end

  let(:connection) { Freddy::Adapters.determine.connect(config) }
  let(:destination) { random_destination }
  let(:payload) { {pay: 'load'} }
  let(:msg_handler_adapter_factory) { double(for: msg_handler_adapter) }
  let(:msg_handler_adapter) { Freddy::MessageHandlerAdapters::NoOpHandler.new }
  let(:prefetch_buffer_size) { 2 }
  let(:thread_pool) { Thread.pool(prefetch_buffer_size) }

  after do
    connection.close
  end

  context 'when no messages' do
    let(:channel) { connection.create_channel }

    it "doesn't call passed block" do
      consumer.consume do
        @message_received = true
      end
      default_sleep

      expect(@message_received).to be_falsy
    end
  end

  context 'when thread pool is full' do
    let(:prefetch_buffer_size) { 1 }
    let(:msg_count) { prefetch_buffer_size + 1 }
    let(:channel) { connection.create_channel(prefetch: prefetch_buffer_size) }
    let(:mutex) { Mutex.new }
    let(:consume_lock) { ConditionVariable.new }
    let(:queue) { channel.queue(destination) }

    after do
      # Release the final queued message before finishing the test to avoid
      # bunny warnings.
      process_message
    end

    it 'does not consume more messages' do
      consumer.consume do
        wait_until_released
      end

      msg_count.times { deliver_message }

      sleep default_sleep
      expect(queue.message_count).to eq(msg_count - prefetch_buffer_size)

      process_message
      expect(queue.message_count).to eq(0)
    end

    def process_message
      release_consume_lock
      sleep default_sleep
    end

    def deliver_message
      channel.default_exchange.publish('{}', routing_key: destination)
    end

    def wait_until_released
      mutex.synchronize { consume_lock.wait(mutex) }
    end

    def release_consume_lock
      mutex.synchronize { consume_lock.broadcast }
    end
  end
end
