amqp    = require 'amqp'
logger  = require 'winston'

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
      callback() if (typeof callback is 'function') if !@connection_created?
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

  onQueueReady: (queueReadyCallback) ->
    respondTo: (destination, callback) =>
      @request.respondTo destination, queueReadyCallback, callback

  deliverWithAck: (destination, message, callback) ->
    @producer.deliverWithAck destination, message, DEFAULT_TIMEOUT, callback

  deliverWithResponse: (destination, message, callback) ->
    @producer.produceWithResponse destination, message, DEFAULT_TIMEOUT, callback

  respondTo: (destination, callback) ->
    @request.respondTo destination, null, callback


  class Producer
    constructor: (@connection) ->
      @request = new Request(@connection, new Consumer(@connection), this)

    produce: (destination, message, options = {}) ->
      @connection.publish destination, message, options

    deliverWithAck: (destination, message, timeoutSeconds, callback) ->
      @request.request destination, message, timeoutSeconds, {headers: {messageWithAck: true}}, (message, msgHandler) =>
        callback message.error if (typeof callback is 'function')

    produceWithResponse: (destination, message, timeoutSeconds, callback) ->
      @request.request destination, message, timeoutSeconds, {}, (message, msgHandler) =>
        callback message, msgHandler if (typeof callback is 'function')

  class Consumer
    constructor: (@connection) ->

    consume: (destination, queueReadyCallback, messageCallback) ->
      @connection.queue destination, {exclusive: true}, (queue) =>
        queueReadyCallback(queue) if (typeof queueReadyCallback is 'function') 
        @consumeFromQueue queue, messageCallback

    consumeFromQueue: (queue, callback) ->
      queue.subscribe (message, headers, deliveryInfo) =>
        # callback @_parseMessage(message.data), new MessageHandler(headers, deliveryInfo)
        callback message, new MessageHandler(headers, deliveryInfo)

    _parseMessage: (octetStream) ->
      JSON.parse Buffer(octetStream).toString()

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

module.exports = Freddy