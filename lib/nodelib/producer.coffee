Consumer = require './consumer'
Request  = require './request'
logger  = require 'winston'

class Producer
  constructor: (@connection, topicName) ->
    @request = new Request(@connection, new Consumer(@connection, topicName), this)
    @topicExchange = @connection.exchange(topicName, {type: 'topic', autoDelete: false})

  produce: (destination, message, options = {}) ->
    throw "Destination must be provided as a string" if (!destination? or !(typeof destination is 'string'))
    throw "Message must be provided" if !message?
    @topicExchange.publish destination, message, options
    @connection.publish destination, message, options

  deliverWithAck: (destination, message, timeoutSeconds, callback) ->
    @request.request destination, message, timeoutSeconds, {headers: {'message_with_ack': true}}, (message, msgHandler) =>
      callback message.error if (typeof callback is 'function')

  produceWithResponse: (destination, message, timeoutSeconds, callback) ->
    @request.request destination, message, timeoutSeconds, {}, (message, msgHandler) =>
      callback message, msgHandler if (typeof callback is 'function')

module.exports = Producer