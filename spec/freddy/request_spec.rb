require 'messaging_spec_helper'
require 'messaging/request'

module Messaging
  describe Request do

    default_let
    let(:req) { Request.new }

    it 'raises empty request exception when requesting without callback' do 
      expect { req.request destination, payload }.to raise_error Request::EmptyRequest
    end

    it 'raises empty responder exception when responding without callback' do 
      expect {@responder = req.respond_to destination }.to raise_error Request::EmptyResponder
    end
    
  end
end