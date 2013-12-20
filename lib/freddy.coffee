amqp     = require 'amqp'
Producer = require './nodelib/producer'
Consumer = require './nodelib/consumer'
Request  = require './nodelib/request'
EventEmitter = require('events').EventEmitter

class Freddy extends EventEmitter

  DEFAULT_TIMEOUT = 3
  FREDDY_TOPIC_NAME = 'freddy-topic'

  constructor: (amqpUrl, @logger) ->
    @logger ?= require 'winston'
    @initializeConnection amqpUrl

  initializeConnection: (amqpUrl) =>
    @connection = amqp.createConnection({url: amqpUrl, reconnect: true})
    @connection.on 'ready', @onConnectionRestored
    @connection.once 'ready', @onConnectionReady
    @connection.on 'error', @onConnectionError

  onConnectionReady: () =>
    @producer = new Producer @connection, FREDDY_TOPIC_NAME, @logger
    @consumer = new Consumer @connection, FREDDY_TOPIC_NAME, @logger
    @request = new Request @connection, @consumer, @producer, @logger
    @emit 'ready'
    @logger.info 'Amqp connection created' 

  onConnectionRestored: () =>
    if @producer?
      @logger.info "Amqp connection restored"
      @emit 'restored'

  onConnectionError: (error) =>
    @emit 'error', error
    @logger.info "Error in amqp connection: #{error}"

  shutdown: ->
    @connection.end()

  deliver: (destination, message) ->
    @producer.produce destination, message

  withTimeout: (timeoutSeconds) ->
    customTimeoutProducer = 
      deliverWithAck: (destination, message, callback) =>
        @request.deliverWithAck destination, message, timeoutSeconds, callback
      deliverWithResponse: (destination, message, callback) =>
        @request.deliverWithResponse destination, message, timeoutSeconds, callback
    customTimeoutProducer

  deliverWithAck: (destination, message, callback) ->
    @request.deliverWithAck destination, message, DEFAULT_TIMEOUT, callback

  deliverWithResponse: (destination, message, callback) ->
    @request.deliverWithResponse destination, message, DEFAULT_TIMEOUT, callback

  respondTo: (destination, callback) ->
    @request.respondTo destination, callback

  tapInto: (pattern, callback) ->
    @consumer.tapInto pattern, callback

module.exports = Freddy