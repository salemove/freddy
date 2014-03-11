q = require 'q'

class ResponderHandler

  constructor: (@channel) ->
    @consumerTag = q.defer()
    @queue = null

  cancel: ->
    @consumerTag.promise.then (consumerTag) =>
      q(@channel.cancel(consumerTag))

  ready: (consumerTag) ->
    @consumerTag.resolve(consumerTag)

module.exports = ResponderHandler