async   = require 'async'
logger  = require 'winston'

class Consumer
  constructor: (@connection) ->

  consume: (destination, queueReadyCallback, messageCallback) ->
    consumerHandler = new ConsumerHandler
    @connection.queue destination, {exclusive: true}, (queue) =>
      queueReadyCallback(queue) if (typeof queueReadyCallback is 'function') 
      @consumeFromQueue queue, messageCallback, consumerHandler
    return consumerHandler

  consumeFromQueue: (queue, callback, consumerHandler = null) ->
    consumerHandler ?= new ConsumerHandler
    consumerHandler.setQueue queue
    queue.subscribe( 
      (message, headers, deliveryInfo) =>
        if message?.data?
          #when message was sent with bunny, then need to parse the JSON
          message = @_parseMessage message.data
        callback message, new MessageHandler(headers, deliveryInfo) if message?
      ).addCallback (ok) =>
        consumerHandler.setConsumer ok.consumerTag
    return consumerHandler

  _parseMessage: (octetStream) ->
    JSON.parse Buffer(octetStream).toString()

  class ConsumerHandler
    setConsumer: (@consumerTag) ->

    setQueue: (@queue) ->

    cancel: (unsubCallback) ->
      tries = 0
      async.whilst () =>
          tries < 10
        ,(callback) =>
          if @queue and @consumerTag
            @queue.unsubscribe(@consumerTag).addCallback(unsubCallback)
            tries = 10
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