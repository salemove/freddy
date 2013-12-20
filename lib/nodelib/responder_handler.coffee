async   = require 'async'
EventEmitter = require('events').EventEmitter

class ResponderHandler extends EventEmitter
    setConsumerTag: (@consumerTag) ->

    setQueue: (@queue) ->

    cancel: ->
      #when cancel is called immediately, then the subscription might not have been started yet
      tries = 0
      async.whilst () =>
          tries < 10
        , (callback) =>
          if @queue and @consumerTag
            @queue.unsubscribe(@consumerTag).addCallback () =>
              @emit('cancelled')
          else 
            tries += 1
            setTimeout callback, 10
        , () =>

    destroyDestination: ->
      @queue.destroy

module.exports = ResponderHandler