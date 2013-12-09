should = require 'should'
Freddy = require '../lib/freddy'
logger = require 'winston'

describe 'Freddy', ->

  TEST_MESSAGE = 
    test: 'data'

  beforeEach (done) ->
    @freddy = new Freddy('amqp://guest:guest@localhost:5672', done)
    @default_producer = =>
      @freddy.deliver @randomDest, TEST_MESSAGE
    @default_ack_producer = (callback) =>
      @freddy.deliverWithAck @randomDest, TEST_MESSAGE, callback
    @customProduce = (producer, callback) ->
      @freddy.onQueueReady(producer).respondTo @randomDest, callback
    @ackCustomProduce = (producer, callback) ->
      @freddy.onQueueReady(producer).respondTo @randomDest, callback
    @produceRespond = (callback) ->
      @freddy.onQueueReady(@default_producer).respondTo @randomDest, callback
    @ackProduceRespond = (callback) ->
      @freddy.onQueueReady(@default_ack_producer).respondTo @randomDest, callback

  uniqueId = ->
    id = ""
    id += Math.random().toString(36).substr(2) while id.length < 32
    id.substr 0, 32

  beforeEach () ->
    @randomDest = uniqueId()

  it 'exists', ->
    should.exist Freddy

  it 'can produce messages', ->
    @freddy.deliver @randomDest, TEST_MESSAGE

  describe 'when responding to messages', ->
    it 'can respond', ->
      @freddy.respondTo @randomDest, (message, msgHandler) =>

    it 'receives sent messages', (done) ->
      @produceRespond (message, msgHandler) =>
        message.should.have.property('test')
        done()

  describe 'with messages that need acknowledgement', ->
    it 'can produce', ->
      @freddy.deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
        (typeof error).should.equal 'string'

    it 'can produce with custom timeout', ->
      @freddy.withTimeout(1).deliverWithAck @randomDest, TEST_MESSAGE

    it 'receives the message', (done) ->
      @ackProduceRespond (message, msgHandler) =>
        done()

    it 'can ack message', (done) ->
      @ackProduceRespond (message, msgHandler) =>
        msgHandler.ack
        done()

    it 'returns no error if message was acked', (done) ->
      producer = () =>
        @freddy.deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
          error.should.not.be.ok
          done()

      @ackCustomProduce producer, (message, msgHandler) =>
        msgHandler.ack()

    it 'returns error if message was not acked', (done) ->
      producer = () =>
        @freddy.withTimeout(0.01).deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
          error.should.be.ok
          done()
      @ackCustomProduce producer

    it 'returns error if message was nacked', (done) ->
      producer = () =>
        @freddy.deliverWithAck @randomDest, TEST_MESSAGE, (error) =>
          error.should.be.ok
          done()
      @ackCustomProduce producer, (message, msgHandler) =>
        msgHandler.nack

  describe 'with messages that need response', ->
    it 'can produce', ->
      @freddy.deliverWithResponse @randomDest, TEST_MESSAGE

    it 'can produce with custom timeout', ->
      @freddy.withTimeout(1).deliverWithResponse @randomDest, TEST_MESSAGE

    it 'receives the request', (done) ->
      @ackProduceRespond () =>
        done()

    it 'sends the response to the requester', (done) ->
      producer = () =>
        @freddy.deliverWithResponse @randomDest, TEST_MESSAGE, (message, msgHandler) =>
          message.my.should.equal 'response'
          done()
      @ackCustomProduce producer, (message, msgHandler) =>
        msgHandler.ack {my: 'response'}

    it 'sends error the requester if message was nacked', (done) ->
      producer = () =>
        @freddy.deliverWithResponse @randomDest, TEST_MESSAGE, (message, msgHandler) =>
          message.should.have.property('error')
          done()

      @ackCustomProduce producer, (message, msgHandler) =>
        msgHandler.nack()