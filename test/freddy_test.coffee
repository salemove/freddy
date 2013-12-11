should = require 'should'
Freddy = require '../lib/freddy'
logger = require 'winston'
sinon  = require 'sinon'

describe 'Freddy', ->

  TEST_MESSAGE = 
    test: 'data'

  beforeEach (done) ->
    @freddy = new Freddy('amqp://guest:guest@localhost:5672')
    @respond = (callback) =>
      @freddy.respondTo @randomDest, callback
    @deliver = () =>
      @freddy.deliver @randomDest, TEST_MESSAGE
    @deliverResponse = (callback) =>
      @freddy.deliverWithResponse @randomDest, TEST_MESSAGE, callback
    @deliverAck = (callback) =>
      @freddy.deliverWithAck @randomDest, TEST_MESSAGE, callback
    @tap = (callback) =>
      @freddy.tapInto @randomDest, callback
    @freddy.on 'ready', () =>
      previousFunc = @freddy.consumer._createQueue
      @queueCreatorStub = sinon.stub @freddy.consumer, "_createQueue", (destination, options, callback) ->
        previousFunc.call this, destination, {exclusive: true}, callback
      done()

  uniqueId = ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < 32
    id.substr 0, 32

  beforeEach () ->
    @randomDest = uniqueId()

  it 'exists', ->
    should.exist Freddy

  it 'can produce messages', ->
    @deliver()

  describe 'when responding to messages', ->
    it 'can respond', ->
      @respond (message, msgHandler) =>

    it 'receives sent messages', (done) ->
      handler = @respond (message, msgHandler) =>
        message.should.have.property('test')
        done()
      handler.on 'ready', () =>
        @deliver()

  describe 'with messages that need acknowledgement', ->
    it 'can produce', ->
      @freddy.deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
        (typeof error).should.equal 'string'

    it 'can produce with custom timeout', ->
      @freddy.withTimeout(1).deliverWithAck @randomDest, TEST_MESSAGE

    it 'receives the message', (done) ->
      @respond (message, msgHandler) =>
        done()
      @deliverAck () =>

    it 'can ack message', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.ack
        done()
      @deliverAck () =>

    it 'returns no error if message was acked', (done) ->
      handler = @respond (message, msgHandler) =>
        msgHandler.ack()
      @deliverAck (error) =>
        error.should.not.be.ok
        done()


    it 'returns error if message was not acked', (done) ->
      @freddy.withTimeout(0.01).deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
        error.should.be.ok
        done()

    it 'returns error if message was nacked', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.nack
      @deliverAck (error) =>
        error.should.be.ok
        done()


  describe 'with messages that need response', ->
    it 'can deliver', ->
      @deliver()

    it 'can deliver with custom timeout', ->
      @freddy.withTimeout(1).deliverWithResponse @randomDest, TEST_MESSAGE

    it 'receives the request', (done) ->
      responderHandler = @respond () =>
        done()
      responderHandler.on 'ready', @deliver

    it 'sends the response to the requester', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.ack {my: 'response'}
      @deliverResponse (message, msgHandler) =>
        message.my.should.equal 'response'
        done()

    it 'sends error the requester if message was nacked', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.nack()
      @deliverResponse (message) =>
        message.should.have.property('error')
        done()

    it 'can cancel listening for messages', (done) ->
      messageCount = 0
      handler = @respond (message, msgHandler) =>
        messageCount += 1
      handler.on 'ready', =>
        @deliver()
        handler.cancel()
      handler.on 'cancelled', =>
        @deliver()
        setTimeout () =>
          messageCount.should.equal 1
          done()
        , 10

  describe 'when tapping', ->
    it 'can tap', (done) ->
      handler = @tap ->
        done()
      handler.on 'ready', @deliver

    it 'has the destination', (done) ->
      handler = @freddy.tapInto "easy.*.easy.*", (message, destination) ->
        destination.should.equal "easy.come.easy.go"
        done()
      handler.on 'ready', () =>
        @freddy.deliver "easy.come.easy.go", {}

    it "doesn't consume message", (done) ->
      
      tap_received = (in_tap, in_respond, next) =>
        @tap_received = true if in_tap?
        @respond_received = true if in_respond?
        if !@doneCalled?
          if @tap_received and @respond_received
            next()
            @doneCalled = true
      @tap () =>
        tap_received true, false, done
      handler = @respond () =>
        tap_received false, true, done
      handler.on 'ready', @deliver

    it "allows * wildcard", (done) ->
      handler = @freddy.tapInto "somebody.*.love", () =>
        done()
      handler.on 'ready', () =>
        @freddy.deliver "somebody.to.love", {}

    it "allows # wildcard", (done) ->
      handler = @freddy.tapInto "i.#.free", () =>
        done()
      handler.on 'ready', () =>
        @freddy.deliver "i.want.to.break.free", {}