#Allow responder to use simple ack and nack and responding with an object
#through an unified interface

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
      
module.exports = MessageHandler