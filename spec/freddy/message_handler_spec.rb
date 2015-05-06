require 'spec_helper'

describe Freddy::MessageHandler do

  default_let

  def default_consume(&block)
    freddy.respond_to destination do |payload, msg_handler|
      @msg_handler = msg_handler
      block.call payload, msg_handler if block
    end
  end

  def produce
    freddy.deliver destination, payload do end
    default_sleep
  end

  it 'has properties about message' do
    properties = nil
    default_consume do |payload, msg_handler|
      properties = msg_handler.properties
    end
    deliver
    expect(properties).not_to be_nil
  end

  it 'can ack message' do
    default_consume do |payload, msg_handler|
      msg_handler.ack
    end
    produce
    expect(@msg_handler.error).to be_nil
  end

  it 'can nack message' do
    default_consume do |payload, msg_handler|
      msg_handler.nack "bad message"
    end
    produce
    expect(@msg_handler.error).not_to be_nil
  end

  it 'can ack with response' do
    default_consume do |payload, msg_handler|
      msg_handler.ack(ack: 'smack')
    end
    produce

    expect(@msg_handler.error).to be_nil
    expect(@msg_handler.response).not_to be_nil
  end

end
