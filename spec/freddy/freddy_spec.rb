require 'spec_helper'

describe Freddy do
  let(:freddy) { described_class.build(logger, config) }

  let(:destination)  { random_destination }
  let(:destination2) { random_destination }
  let(:payload)      { {pay: 'load'} }

  def respond_to(&block)
    freddy.respond_to(destination, &block)
  end

  context 'when making a send-and-forget request' do
    context 'with timeout' do
      it 'removes the message from the queue after the timeout' do
        # Assume that there already is a queue. Otherwise will get an early
        # return.
        freddy.channel.queue(destination)

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
        freddy.channel.queue(destination)

        freddy.deliver(destination, {})
        default_sleep # to ensure everything is properly cleaned

        processed_after_timeout = false
        respond_to { processed_after_timeout = true }
        default_sleep

        expect(processed_after_timeout).to be(true)
      end
    end
  end

  context 'when making a synchronized request' do
    it 'returns response as soon as possible' do
      respond_to { |payload, msg_handler| msg_handler.success(res: 'yey') }
      response = freddy.deliver_with_response(destination, {a: 'b'})

      expect(response).to eq(res: 'yey')
    end

    it 'raises an error if the message was errored' do
      respond_to { |payload, msg_handler| msg_handler.error(error: 'not today') }

      expect {
        freddy.deliver_with_response(destination, payload)
      }.to raise_error(Freddy::InvalidRequestError) {|error|
        expect(error.response).to eq(error: 'not today')
      }
    end

    it 'does not leak consumers' do
      respond_to { |payload, msg_handler| msg_handler.success(res: 'yey') }

      old_count = freddy.channel.consumers.keys.count

      response1 = freddy.deliver_with_response(destination, {a: 'b'})
      response2 = freddy.deliver_with_response(destination, {a: 'b'})

      expect(response1).to eq(res: 'yey')
      expect(response2).to eq(res: 'yey')

      new_count = freddy.channel.consumers.keys.count
      expect(new_count).to be(old_count + 1)
    end

    it 'responds to the correct requester' do
      respond_to { |payload, msg_handler| msg_handler.success(res: 'yey') }

      response = freddy.deliver_with_response(destination, payload)
      expect(response).to eq(res: 'yey')

      expect {
        freddy.deliver_with_response(destination2, payload)
      }.to raise_error(Freddy::InvalidRequestError)
    end

    context 'when queue does not exist' do
      it 'gives a no route error' do
        begin
          Timeout::timeout(0.5) do
            expect {
              freddy.deliver_with_response(destination, {a: 'b'}, timeout: 3)
            }.to raise_error(Freddy::InvalidRequestError) {|error|
              expect(error.response).to eq(error: 'Specified queue does not exist')
            }
          end
        rescue Timeout::Error
          fail('Received a timeout error instead of the no route error')
        end
      end
    end

    context 'on timeout' do
      it 'gives timeout error' do
        respond_to { |payload, msg_handler| sleep 0.2 }

        expect {
          freddy.deliver_with_response(destination, {a: 'b'}, timeout: 0.1)
        }.to raise_error(Freddy::TimeoutError) {|error|
          expect(error.response).to eq(error: 'RequestTimeout', message: 'Timed out waiting for response')
        }
      end

      context 'with delete_on_timeout is set to true' do
        it 'removes the message from the queue' do
          # Assume that there already is a queue. Otherwise will get an early
          # return.
          freddy.channel.queue(destination)

          expect {
            freddy.deliver_with_response(destination, {}, timeout: 0.1)
          }.to raise_error(Freddy::TimeoutError)
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
          freddy.channel.queue(destination)

          expect {
            freddy.deliver_with_response(destination, {}, timeout: 0.1, delete_on_timeout: false)
          }.to raise_error(Freddy::TimeoutError)
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
    def tap(custom_destination = destination, &block)
      freddy.tap_into(custom_destination, &block)
    end

    it 'receives messages' do
      tap {|msg| @tapped_message = msg }
      deliver

      wait_for { @tapped_message }
      expect(@tapped_message).to eq(payload)
    end

    it 'has the destination' do
      tap "somebody.*.love" do |message, destination|
        @destination = destination
      end
      deliver "somebody.to.love"

      wait_for { @destination }
      expect(@destination).to eq("somebody.to.love")
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

    it "allows * wildcard" do
      tap("somebody.*.love") { @tapped = true }

      deliver "somebody.to.love"

      wait_for { @tapped }
      expect(@tapped).to be(true)
    end

    it "* matches only one word" do
      tap("somebody.*.love") { @tapped = true }

      deliver "somebody.not.to.love"

      default_sleep
      expect(@tapped).to be_falsy
    end

    it "allows # wildcard" do
      tap("i.#.free") { @tapped = true }

      deliver "i.want.to.break.free"

      wait_for { @tapped }
      expect(@tapped).to be(true)
    end
  end
end
