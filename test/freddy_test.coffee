should = require 'should'
Freddy = require '../lib/freddy'
logger = require 'winston'
winston = require 'winston'
sinon  = require 'sinon'
TestHelper = (require './test_helper')

describe 'Freddy', ->

  TEST_MESSAGE =
    test: 'data'

  beforeEach (done) ->
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

    Freddy.connect('amqp://guest:guest@localhost:5672', TestHelper.logger('warn')).then (@freddy) =>
      done()
    , (err) ->
      done(err)

    @randomDest = uniqueId()

  afterEach (done) ->
    TestHelper.connect (connection) =>
      TestHelper.deleteExchange connection, 'freddy-topic'
    .then =>
      @freddy.shutdown()
    .then ->
      done()

  uniqueId = ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < 32
    id.substr 0, 32

  it 'exists', ->
    should.exist Freddy

  it 'can produce messages', ->
    @deliver()

  context 'with correct amqp url', ->
    it 'can connect to amqp', (done) ->
      Freddy.connect(TestHelper.amqpUrl, TestHelper.logger('warn')).then =>
        done()
      , =>
        done Error("Connection should have succeeded, but failed")

  context 'with incorrect amqp url', ->
    it 'cannot connect', (done) ->
      Freddy.connect('amqp://wrong:wrong@localhost:9000', TestHelper.logger('warn')).then (@freddy) ->
        done(Error("Connection should have failed, but succeed"))
      , =>
        done()

  describe 'when responding to messages', ->
    it 'can respond', ->
      @respond (message, msgHandler) =>

    it 'receives sent messages', (done) ->
      @respond (message, msgHandler) =>
        message.should.have.property('test')
        done()
      .then =>
        @deliver()

    it 'catches errors', (done) ->
      myError = new Error('catch me')
      Freddy.addErrorListener (err) ->
        err.should.eql(myError)
        done()

      @freddy.respondTo @randomDest, (message, msgHandler) ->
        throw myError
      .then =>
        @freddy.deliver @randomDest, {}

  describe 'with messages that need acknowledgement', ->
    it 'can produce', ->
      @freddy.deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
        error.should.be.ok

    it 'can produce with custom timeout', ->
      @freddy.deliverWithAckAndOptions @randomDest, TEST_MESSAGE, timeout: 1

    it 'receives the message', (done) ->
      @respond (message, msgHandler) =>
        done()
      .then =>
        @deliverAck =>

    it 'can ack message', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.ack()
        done()
      .then =>
        @deliverAck =>

    it 'returns no error if message was acked', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.ack()
      .then =>
        @deliverAck (error) =>
          error.should.not.be.ok
          done()


    it 'returns error if message was not acked', (done) ->
      @freddy.deliverWithAckAndOptions @randomDest, TEST_MESSAGE, {timeout: 0.01}, (error) =>
        error.should.be.ok
        done()

    it 'returns error if message was nacked', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.nack()
      .then =>
        @deliverAck (error) =>
          error.should.be.ok
          done()


  describe 'with messages that need response', ->
    it 'can deliver', ->
      @deliver()

    it 'can deliver with custom timeout', ->
      @freddy.deliverWithResponseAndOptions @randomDest, TEST_MESSAGE, timeout: 1

    it 'receives the request', (done) ->
      @respond =>
        done()
      .then =>
        @deliver()

    it 'sends the response to the requester', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.ack {my: 'response'}
      .then =>
        @deliverResponse (message, msgHandler) =>
          message.my.should.equal 'response'
          done()

    it 'sends error to the requester if message was nacked', (done) ->
      @respond (message, msgHandler) =>
        msgHandler.nack()
      .then =>
        @deliverResponse (message) =>
          message.should.have.property('error')
          done()

    it 'can cancel listening for messages', (done) ->
      messageCount = 0
      @respond (message, msgHandler) =>
        messageCount += 1
        @responderHandler.cancel().then =>
          @deliver()
          setTimeout =>
            messageCount.should.equal 1
            done()
          , 10
      .then (@responderHandler) =>
        @deliver()

  describe 'when tapping', ->
    it 'can tap', (done) ->
      @tap ->
        done()
      .then =>
        @deliver()

    it 'has the destination', (done) ->
      @freddy.tapInto "easy.*.easy.*", (message, destination) ->
        destination.should.equal "easy.come.easy.go"
        done()
      .then =>
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
      @respond () =>
        tap_received false, true, done
      .then =>
        @deliver()

    it "allows * wildcard", (done) ->
      @freddy.tapInto "somebody.*.love", () =>
        done()
      .then =>
        @freddy.deliver "somebody.to.love", {}

    it "allows # wildcard", (done) ->
      @freddy.tapInto "i.#.free", () =>
        done()
      .then =>
        @freddy.deliver "i.want.to.break.free", {}