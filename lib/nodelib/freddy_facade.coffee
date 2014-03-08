q   = require 'q'

class FreddyFacade

  DEFAULT_TIMEOUT = 3

  constructor: (@consumer, @producer, @request, @onShutdown) ->
    @deliver = @producer.produce
    @respondTo = @request.respondTo
    @tapInto = @consumer.tapInto

  shutdown: ->
    q(@onShutdown())

  deliverWithAck: (destination, message, callback) ->
    @deliverWithAckAndOptions destination, message, {}, callback

  deliverWithAckAndOptions: (destination, message, options, callback) ->
    options ||= {}
    options.timeout ||= DEFAULT_TIMEOUT
    options.headers = { message_with_ack: true }
    @request.deliverWithAckAndOptions destination, message, options, callback

  deliverWithResponse: (destination, message, callback) ->
    @deliverWithResponseAndOptions destination, message, {}, callback

  deliverWithResponseAndOptions: (destination, message, options, callback) ->
    options ||= {}
    options.timeout ||= DEFAULT_TIMEOUT
    @request.deliverWithResponseAndOptions destination, message, options, callback

module.exports = FreddyFacade