require 'messaging_spec_helper'
require 'messaging/request'

module Messaging
  describe Request do

    default_let

    let(:request) { freddy.request }

    it 'raises empty responder exception when responding without callback' do
      expect {@responder = request.respond_to destination, false }.to raise_error Request::EmptyResponder
    end

  end
end
