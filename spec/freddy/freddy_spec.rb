require 'spec_helper'

describe Freddy do
  let(:freddy) { described_class.build(logger, **config) }

  let(:destination)  { random_destination }
  let(:destination2) { random_destination }
  let(:payload)      { { pay: 'load' } }

  before do
    @bunny = Bunny.new(config)
    @bunny.start
  end

  after do
    @bunny.close
    freddy.close
  end

  def respond_to(&)
    freddy.respond_to(destination, &)
  end

  context 'when making a send-and-forget request' do
    context 'with timeout' do
      it 'removes the message from the queue after the timeout' do
        # Assume that there already is a queue. Otherwise will get an early
        # return.
        consumer = freddy.respond_to(destination) {}
        consumer.shutdown

        freddy.deliver(destination, {}, timeout: 0.1)
        sleep 0.2

        processed_after_timeout = false
        respond_to { processed_after_timeout = true }
        default_sleep

        expect(processed_after_timeout).to be(false)
      end
    end

    context 'without timeout' do
      it 'keeps the message in the queue' do
        # Assume that there already is a queue. Otherwise will get an early
        # return.
        consumer = freddy.respond_to(destination) {}
        consumer.shutdown

        freddy.deliver(destination, {})
        default_sleep # to ensure everything is properly cleaned

        processed_after_timeout = false
        respond_to { processed_after_timeout = true }
        default_sleep

        expect(processed_after_timeout).to be(true)
      end
    end

    context 'with compress' do
      it 'compresses the payload' do
        expect(Freddy::Encoding).to receive(:compress).with(anything, 'zlib').and_call_original

        freddy.tap_into(destination) { |msg| @tapped_message = msg }
        freddy.deliver(destination, payload, compress: 'zlib')
        default_sleep

        wait_for { @tapped_message }
        expect(@tapped_message).to eq(payload)
      end
    end

    context 'without compress' do
      it 'does not compress the payload' do
        freddy.tap_into(destination) { |msg| @tapped_message = msg }
        deliver

        wait_for { @tapped_message }
        expect(@tapped_message).to eq(payload)
      end
    end

    it 'accepts custom headers' do
      headers = nil
      queue = exclusive_subscribe do |_info, metadata, _payload|
        headers = metadata[:headers]
      end
      freddy.deliver(queue, payload, headers: { 'foo' => 'bar' })

      wait_for { headers }
      expect(headers).to include({ 'foo' => 'bar' })
    end
  end

  def exclusive_subscribe(&)
    channel = @bunny.create_channel
    queue = channel.queue('', exclusive: true)
    queue.subscribe(&)
    queue.name
  end

  context 'when making a synchronized request' do
    it 'returns response as soon as possible' do
      respond_to { |_payload, msg_handler| msg_handler.success(res: 'yey') }
      response = freddy.deliver_with_response(destination, a: 'b')

      expect(response).to eq(res: 'yey')
    end

    it 'raises an error if the message was errored' do
      respond_to { |_payload, msg_handler| msg_handler.error(error: 'not today') }

      expect do
        freddy.deliver_with_response(destination, payload)
      end.to raise_error(Freddy::InvalidRequestError) { |error|
        expect(error.response).to eq(error: 'not today')
      }
    end

    it 'responds to the correct requester' do
      respond_to { |_payload, msg_handler| msg_handler.success(res: 'yey') }

      response = freddy.deliver_with_response(destination, payload)
      expect(response).to eq(res: 'yey')

      expect do
        freddy.deliver_with_response(destination2, payload)
      end.to raise_error(Freddy::InvalidRequestError)
    end

    context 'when queue does not exist' do
      it 'gives a no route error' do
        expect do
          freddy.deliver_with_response(destination, { a: 'b' }, timeout: 1)
        end.to raise_error(Freddy::InvalidRequestError) { |error|
          expect(error.response).to eq(error: 'Specified queue does not exist')
        }
      end
    end

    context 'when timeout' do
      it 'gives timeout error' do
        respond_to { |_payload, _msg_handler| sleep 0.2 }

        expect do
          freddy.deliver_with_response(destination, { a: 'b' }, timeout: 0.1)
        end.to raise_error(Freddy::TimeoutError) { |error|
          expect(error.response).to eq(error: 'RequestTimeout', message: 'Timed out waiting for response')
        }
      end

      context 'with delete_on_timeout is set to true' do
        it 'removes the message from the queue' do
          # Assume that there already is a queue. Otherwise will get an early
          # return.
          consumer = freddy.respond_to(destination) {}
          consumer.shutdown

          expect do
            freddy.deliver_with_response(destination, {}, timeout: 0.1)
          end.to raise_error(Freddy::TimeoutError)
          default_sleep # to ensure everything is properly cleaned

          processed_after_timeout = false
          respond_to { processed_after_timeout = true }
          default_sleep

          expect(processed_after_timeout).to be(false)
        end
      end

      context 'with delete_on_timeout is set to false' do
        it 'removes the message from the queue' do
          # Assume that there already is a queue. Otherwise will get an early
          # return.
          consumer = freddy.respond_to(destination) {}
          consumer.shutdown

          expect do
            freddy.deliver_with_response(destination, {}, timeout: 0.1, delete_on_timeout: false)
          end.to raise_error(Freddy::TimeoutError)
          default_sleep # to ensure everything is properly cleaned

          processed_after_timeout = false
          respond_to { processed_after_timeout = true }
          default_sleep

          expect(processed_after_timeout).to be(true)
        end
      end
    end
  end

  describe 'when tapping' do
    def tap(custom_destination = destination, &)
      freddy.tap_into(custom_destination, &)
    end

    it 'receives messages' do
      tap { |msg| @tapped_message = msg }
      deliver

      wait_for { @tapped_message }
      expect(@tapped_message).to eq(payload)
    end

    it 'has the destination' do
      tap 'somebody.*.love' do |_message, destination|
        @destination = destination
      end
      deliver 'somebody.to.love'

      wait_for { @destination }
      expect(@destination).to eq('somebody.to.love')
    end

    it "doesn't consume the message" do
      tap { @tapped = true }
      respond_to { @message_received = true }

      deliver

      wait_for { @tapped }
      wait_for { @message_received }
      expect(@tapped).to be(true)
      expect(@message_received).to be(true)
    end

    it 'allows * wildcard' do
      tap('somebody.*.love') { @tapped = true }

      deliver 'somebody.to.love'

      wait_for { @tapped }
      expect(@tapped).to be(true)
    end

    it '* matches only one word' do
      tap('somebody.*.love') { @tapped = true }

      deliver 'somebody.not.to.love'

      default_sleep
      expect(@tapped).to be_falsy
    end

    it 'allows # wildcard' do
      tap('i.#.free') { @tapped = true }

      deliver 'i.want.to.break.free'

      wait_for { @tapped }
      expect(@tapped).to be(true)
    end
  end
end
