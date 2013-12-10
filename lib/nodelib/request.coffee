logger  = require 'winston'

class Request
  constructor: (@connection, @consumer, @producer) ->
    @requests = {}
    #This temporary queue will be created once per lifetime of AmqpRpc and will be cleaned up automatically by rabbitmq
    @responseQueue = null 

  extend: (object, properties) ->
    for key, val of properties
      object[key] = val
    object

  request: (destination, message, timeoutSeconds, options, callback) ->
    correlationId = @_uuid()
    @requests[correlationId] = {
      timeout: @_timeout(timeoutSeconds, correlationId, callback), 
      callback: callback
    }
    @_setupResponseQueue () =>
      @extend options, {correlationId: correlationId, replyTo: @responseQueue}
      @producer.produce destination, message, options

  respondTo: (destination, queueReadyCallback, callback) ->
    @consumer.consume destination, queueReadyCallback, (message, msgHandler) =>
      properties = msgHandler.properties
      if properties.headers?.messageWithAck
        callback(message, msgHandler)
        response = {error: msgHandler.error()}
      else if properties.correlationId
        callback(message, msgHandler)
        error = msgHandler.error()
        if error
          response = {error: error}
        else 
          response = msgHandler.response
      else 
        callback(message, msgHandler)

      if response?
        @producer.produce properties.replyTo, response, {correlationId: properties.correlationId}

  _uuid: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  _timeout: (timeoutSeconds, correlationId, callback) ->
    setTimeout( 
      ()=>
        logger.info "Timeout waiting for response with #{timeoutSeconds} s"
        delete @requests[correlationId]
        callback {error: "Timeout waiting for response"} if (typeof callback is 'function')
      , timeoutSeconds * 1000
      )

  _setupResponseQueue: (next) =>
    if @responseQueue? #reuse same queue
      return next()

    @connection.queue '', {exclusive: true}, (queue) =>
      @responseQueue = queue.name
      @consumer.consumeFromQueue queue, (message, msgHandler) =>
        correlationId = msgHandler.properties.correlationId
        if @requests[correlationId]?
          entry = @requests[correlationId]
          clearTimeout entry.timeout
          delete @requests[correlationId]
          entry.callback message, msgHandler
          
      next()

module.exports = Request