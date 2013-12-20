#Encapsulate the request-response types of messaging
class Request
  constructor: (@connection, @consumer, @producer, @logger) ->
    @requests = {}
    #This temporary queue will be created once per lifetime of AmqpRpc and will be cleaned up automatically by rabbitmq
    @responseQueue = null 

  deliverWithAck: (destination, message, timeoutSeconds, callback) ->
    @_request destination, message, timeoutSeconds, {headers: {'message_with_ack': true}}, (message, msgHandler) =>
      callback message.error if (typeof callback is 'function')

  deliverWithResponse: (destination, message, timeoutSeconds, callback) ->
    @_request destination, message, timeoutSeconds, {}, (message, msgHandler) =>
      callback message, msgHandler if (typeof callback is 'function')

  _request: (destination, message, timeoutSeconds, options, callback) ->
    correlationId = @_uuid()
    @requests[correlationId] = {
      timeout: @_timeout(timeoutSeconds, correlationId, callback), 
      callback: callback
    }
    @_setupResponseQueue () =>
      @_extend options, {correlationId: correlationId, replyTo: @responseQueue}
      @producer.produce destination, message, options

  _extend: (object, properties) ->
    for key, val of properties
      object[key] = val
    object

  respondTo: (destination, callback) ->
    @consumer.consume destination, (message, msgHandler) =>
      properties = msgHandler.properties
      response =  @_responder(properties)(message, msgHandler, callback)
      @producer.produce properties.replyTo, response, {correlationId: properties.correlationId} if response?

  _responder: (properties) ->
    if properties.headers?['message_with_ack']
      responder = @_respondToAck
    else if properties.correlationId
      responder = @_respondToRequest
    else 
      responder = @_respondToSimpleDeliver

  _respondToAck: (message, msgHandler, callback) ->
    callback(message, msgHandler)
    {error: msgHandler.error()}

  _respondToRequest: (message, msgHandler, callback) ->
    callback(message, msgHandler)
    error = msgHandler.error()
    if error
      {error: error}
    else 
      msgHandler.response

  _respondToSimpleDeliver: (message, msgHandler, callback) ->
    callback(message, msgHandler)
    return null #avoid returning anything

  _uuid: ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  _timeout: (timeoutSeconds, correlationId, callback) ->
    setTimeout( 
      ()=>
        @logger.info "Timeout waiting for response with #{timeoutSeconds} s"
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
          @logger.debug "Received request response on #{@responseQueue}"
          entry.callback message, msgHandler
          
      next()

module.exports = Request