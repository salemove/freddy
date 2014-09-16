require 'messaging_spec_helper'

module Messaging
  describe "Node integration" do
    default_let
    let(:freddy) { Freddy.new.tap {|freddy| freddy.use_distinct_connection} }

    context "with node_producer " do
      before(:each) do
        Process.fork do
          system 'spec/node_test_producer'
        end
      end

      it 'receives messages on ruby' do
        received = false
        freddy.respond_to 'node.test.deliver' do
          received = true
        end
        Process.wait
        expect(received).to be(true)
      end

      it 'responds to ruby messages' do
        received_msg = nil
        sleep 0.5
        freddy.deliver_with_response 'node.test.respond', {} do |msg|
          received_msg = msg
        end
        Process.wait
        expect(received_msg).to eq(success: true)
      end
    end
  end
end
