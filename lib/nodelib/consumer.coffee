async   = require 'async'
logger  = require 'winston'
EventEmitter = require('events').EventEmitter

class Consumer
  constructor: (@connection, topicName) ->
    @topicExchange = @connection.exchange(topicName, {type: 'topic', autoDelete: false})

  consume: (destination, callback) ->
    throw "Destination must be provided as a string" if !destination? or !(typeof destination is 'string')
    responderHandler = new ResponderHandler
    @_createQueue destination, {}, (queue) =>
      responderHandler.emit 'ready'
      @consumeFromQueue queue, callback, responderHandler
    return responderHandler

  _createQueue: (destination, options, callback) ->
    @connection.queue destination, options, callback

  consumeFromQueue: (queue, callback, responderHandler = null) ->
    responderHandler ?= new ResponderHandler
    responderHandler.setQueue queue
    subscription = queue.subscribe (message, headers, deliveryInfo) =>
      callback message, new MessageHandler(headers, deliveryInfo) if message?
    subscription.addCallback (ok) =>
        responderHandler.setConsumer ok.consumerTag
    return responderHandler

  tap: (destination, callback) ->
    responderHandler = new ResponderHandler
    @connection.queue '', {exclusive: true}, (queue) =>
      queue.bind(@topicExchange, destination)
      queue.on 'queueBindOk', () =>
        responderHandler.emit 'ready'
      subscription = queue.subscribe (message) =>
        callback message
      subscription.addCallback (ok) =>
        responderHandler.setConsumer ok.consumerTag
    return responderHandler    

  class ResponderHandler extends EventEmitter
    setConsumer: (@consumerTag) ->

    setQueue: (@queue) ->

    cancel: () ->
      tries = 0
      async.whilst () =>
          tries < 10
        , (callback) =>
          if @queue and @consumerTag
            @queue.unsubscribe(@consumerTag).addCallback () =>
              @emit('cancelled')
          else 
            tries += 1
            setTimeout callback, 10
        , () =>

  class MessageHandler
    constructor: (@headers, @properties) ->
      @acked = false

    ack: (response) ->
      @response = response
      @acked = true

    nack: (errorMessage) ->
      @errorMessage = errorMessage
      @acked = false
      @response = {error: errorMessage}

    error: ->
      if !@acked
        if @errorMessage?
          @errorMessage
        else 
          "Responder didn't manually acknowledge message"
      else 
        false

module.exports = Consumer