Consumer = require './consumer'
Request  = require './request'
logger  = require 'winston'

class Producer
  constructor: (@connection) ->
    @request = new Request(@connection, new Consumer(@connection), this)

  produce: (destination, message, options = {}) ->
    @connection.publish(destination, message, options)

  deliverWithAck: (destination, message, timeoutSeconds, callback) ->
    @request.request destination, message, timeoutSeconds, {headers: {'message_with_ack': true}}, (message, msgHandler) =>
      callback message.error if (typeof callback is 'function')

  produceWithResponse: (destination, message, timeoutSeconds, callback) ->
    @request.request destination, message, timeoutSeconds, {}, (message, msgHandler) =>
      callback message, msgHandler if (typeof callback is 'function')

module.exports = Producer