#Encapsulate listening for messages
ResponderHandler = require './responder_handler.coffee'
MessageHandler   = require './message_handler.coffee'
q = require 'q'

class Consumer

  DEFAULT_OPTIONS =
    queue:
      autoDelete: true

  TOPIC_OPTIONS =
    durable: false
    autoDelete: false

  constructor: (@connection, @logger) ->
    @errorListeners = []

  addErrorListener: (listener) ->
    @errorListeners.push listener

  prepare: (@topicName) ->
    q(@connection.createChannel()).then (@channel) =>
      @logger.debug("Channel created for consumer")
      @channel.assertExchange(@topicName, 'topic', TOPIC_OPTIONS)
    .then =>
      @logger.debug("Topic exchange created for consumer")
      q(this)
    , (err) =>
      @logger.error("Failed to prepare Producer: #{err}")
      q.reject(err)

  _ensureQueue: (queue) ->
    if !queue? or !(typeof queue is 'string')
      throw "Destination must be provided as a string"

  consume: (queue, callback) ->
    @consumeWithOptions(queue, DEFAULT_OPTIONS, callback)

  consumeWithOptions: (queue, options, callback) ->
    @_ensureQueue(queue)
    responderHandler = new ResponderHandler(@channel)
    q(@channel.assertQueue(queue, options?.queue)).then (queueObject) =>
      responderHandler.queue = queueObject.queue
      return @_consumeWithQueueReady queueObject.queue, (message, messageObject) =>
        callback(message, new MessageHandler(@logger, messageObject.properties))
    .then (subscription) =>
      responderHandler.ready(subscription.consumerTag)
      q(responderHandler)
    , (err) =>
      @logger.error "Consumer with destination #{queue} exited: #{err}"
      q.reject(err)

  notifyErrorListeners: (error) ->
    for listener in @errorListeners
      try
        listener?(error) if typeof listener is 'function'
      catch err
        @logger.error "Error listener throw error #{err}"


  _consumeWithQueueReady: (queue, callback) ->
    @logger.debug "Consuming messages on #{queue}"
    @channel.consume queue, (messageObject) =>
      return unless messageObject
      @logger.debug "Received message on #{queue}"
      properties = messageObject.properties
      @_parseMessage(messageObject).done (message) =>
        @logger.debug "The message is", message unless properties.headers?.suppressLog
        try
          callback(message, messageObject)
        catch err
          @notifyErrorListeners(err)
          @logger.error "Consuming from #{queue} callback #{callback} threw an error, continuing to listen. #{err}"
        @channel.ack messageObject

  _parseMessage: (messageObject) ->
    try
      q(JSON.parse(messageObject.content.toString()))
    catch err
      @logger.error "Couldn't parse message #{messageObject.content.toString()}, err: #{err}"
      q.reject(err)

  tapInto: (pattern, callback) =>
    responderHandler = new ResponderHandler @channel
    q(@channel.assertQueue('', exclusive: true, autoDelete: true)).then (queueObject) =>
      queueName = queueObject.queue
      responderHandler.queue = queueName
      @channel.bindQueue(queueName, @topicName, pattern).then =>
        q(@_consumeWithQueueReady(queueName, (message, messageObject) =>
          callback(message, messageObject.fields.routingKey)
        ))
    .then (subscription) =>
      responderHandler.ready(subscription.consumerTag)
      q(responderHandler)

module.exports = Consumer
