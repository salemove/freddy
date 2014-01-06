#Encapsulate listening for messages
ResponderHandler = require './responder_handler.coffee'
MessageHandler   = require './message_handler.coffee'

class Consumer
  constructor: (@connection, topicName, @logger) ->
    @topicExchange = @connection.exchange(topicName, {type: 'topic', autoDelete: false})

  consume: (destination, callback) ->
    @_ensureDestination destination
    responderHandler = new ResponderHandler
    @_createQueue destination, {}, (queue) =>
      responderHandler.emit 'ready'
      @consumeFromQueue queue, callback, responderHandler
    return responderHandler

  _ensureDestination: (destination) ->
    if !destination? or !(typeof destination is 'string')
      throw "Destination must be provided as a string" 

  _createQueue: (destination, options, callback) ->
    @connection.queue destination, options, callback

  consumeFromQueue: (queue, callback, responderHandler = null) ->
    responderHandler ?= new ResponderHandler
    responderHandler.setQueue queue
    subscription = queue.subscribe (message, headers, deliveryInfo) =>
      @logger.debug "Received message on #{queue.name}"
      callback message, new MessageHandler(headers, deliveryInfo) if message?
    subscription.addCallback (ok) =>
        responderHandler.setConsumerTag ok.consumerTag
    return responderHandler

  tapInto: (pattern, callback) ->
    responderHandler = new ResponderHandler
    @connection.queue '', {exclusive: true}, (queue) =>
      responderHandler.setQueue queue
      queue.bind(@topicExchange, pattern)
      queue.on 'queueBindOk', () =>
        responderHandler.emit 'ready'
      subscription = queue.subscribe (message, headers, deliveryInfo) =>
        callback message, deliveryInfo.routingKey
      subscription.addCallback (ok) =>
        responderHandler.setConsumerTag ok.consumerTag
    return responderHandler    

module.exports = Consumer