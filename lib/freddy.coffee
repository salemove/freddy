amqp     = require 'amqp'
logger   = require 'winston'
Producer = require './nodelib/producer'
Consumer = require './nodelib/consumer'
Request  = require './nodelib/request'

class Freddy

  DEFAULT_TIMEOUT = 3

  constructor: (@amqpUrl, callback) ->
    @connection = amqp.createConnection({url: @amqpUrl, reconnect: true})
    @connection.on 'ready', () =>
      if @connection_created
        logger.info "Amqp connection restored"
      else 
        logger.info 'Amqp connection created'
      @producer = new Producer @connection if !@producer?
      @request = new Request(@connection, new Consumer(@connection), @producer) if !@request
      callback() if (typeof callback is 'function') and !@connection_created?
      @connection_created = true
    @connection.on 'error', (err) =>
      logger.info "Error in amqp connection: #{err}"

  shutdown: ->
    @connection.end()

  deliver: (destination, message) ->
    @producer.produce destination, message

  withTimeout: (timeoutSeconds) ->
    customTimeoutProducer = 
      deliverWithAck: (destination, message, callback) =>
        @producer.deliverWithAck destination, message, timeoutSeconds, callback
      deliverWithResponse: (destination, message, callback) =>
        @producer.produceWithResponse destination, message, timeoutSeconds, callback
    customTimeoutProducer

  deliverWithAck: (destination, message, callback) ->
    @producer.deliverWithAck destination, message, DEFAULT_TIMEOUT, callback

  deliverWithResponse: (destination, message, callback) ->
    @producer.produceWithResponse destination, message, DEFAULT_TIMEOUT, callback

  respondTo: (destination, callback) ->
    @request.respondTo destination, callback

module.exports = Freddy