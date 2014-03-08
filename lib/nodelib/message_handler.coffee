#Allow responder to use simple ack and nack to respond to messages
q = require 'q'

class MessageHandler

  constructor: (@logger, @properties) ->
    @_responded = q.defer()
    @whenResponded = @_responded.promise

  ack: (response) ->
    @logger.debug("Responder acked with", response)
    @_responded.resolve(response || {})

  nack: (errorMessage) ->
    @logger.debug("Responder nacked with error", errorMessage)
    @_responded.reject(errorMessage || "Message was nacked")

module.exports = MessageHandler