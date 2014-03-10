q   = require 'q'

class FreddyFacade

  DEFAULT_TIMEOUT = 3

  constructor: (@consumer, @producer, @request, @onShutdown) ->
    @deliver = @producer.produce
    @respondTo = @request.respondTo
    @tapInto = @consumer.tapInto
    @deliverWithAckAndOptions = @request.deliverWithAckAndOptions
    @deliverWithResponseAndOptions = @request.deliverWithResponseAndOptions

  shutdown: ->
    q(@onShutdown())

  deliverWithAck: (destination, message, callback) ->
    @deliverWithAckAndOptions destination, message, {}, callback

  deliverWithResponse: (destination, message, callback) ->
    @deliverWithResponseAndOptions destination, message, {}, callback

module.exports = FreddyFacade