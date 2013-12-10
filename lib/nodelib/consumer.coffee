async   = require 'async'
logger  = require 'winston'
EventEmitter = require('events').EventEmitter

class Consumer
  constructor: (@connection) ->

  consume: (destination, messageCallback) ->
    responderHandler = new ResponderHandler
    @connection.queue destination, {exclusive: true}, (queue) =>
      responderHandler.emit 'ready'
      @consumeFromQueue queue, messageCallback, responderHandler
    return responderHandler

  consumeFromQueue: (queue, callback, responderHandler = null) ->
    responderHandler ?= new ResponderHandler
    responderHandler.setQueue queue
    queue.subscribe( 
      (message, headers, deliveryInfo) =>
        callback message, new MessageHandler(headers, deliveryInfo) if message?
      ).addCallback (ok) =>
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