Request     = require '../lib/nodelib/request'
Consumer    = require '../lib/nodelib/consumer'
Producer    = require '../lib/nodelib/producer'
TestHelper  = (require './test_helper')

describe 'Request', ->

  before ->
    @topicName = 'test-topic'

  beforeEach ->
    @options = {}
    @message = 'test'

  beforeEach (done) ->
    TestHelper.connect (@connection) =>
      @producer = new Producer connection, TestHelper.logger('warn')
      @consumer = new Consumer connection, TestHelper.logger('warn')
      @producer.prepare(@topicName)
      .then =>
        @consumer.prepare(@topicName)
      .then =>
        @request = new Request connection, TestHelper.logger('warn')
        done()

  afterEach (done) ->
    TestHelper.deleteExchange(@connection, @topicName)
    .then =>
      @connection.close()
    .then ->
      done()

  context '#prepare', ->
    it 'resolves after done', (done) ->
      @request.prepare(@consumer, @producer).then ->
        done()
      , =>
        done Error("Prepare should have succeeded but failed")

  context 'when prepared', ->
    beforeEach (done) ->
      @request.prepare(@consumer, @producer).then ->
        done()

    context '#deliverWithAckAndOptions', ->
      before ->
        @destination = 'ack-test'
        @subject = =>
          @request.deliverWithAckAndOptions @destination, @message, @options, @callback

      it 'returns error if message was neither acked nor nacked', (done) ->
        @options = timeout: 0.01
        @callback = (error) =>
          error.should.eql("Timeout waiting for response")
          done()
        @subject()

      context 'when message was acked', ->
        beforeEach (done) ->
          @request.respondTo @destination, (message, msgHandler) ->
            msgHandler.ack()
          .then -> done()

        it 'responds with null', (done) ->
          @callback = (error) ->
            error.should.be.nil
            done()
          @subject()

      context 'when message was nacked', ->
        before -> @error = 'no bueno'

        beforeEach (done) ->
          @request.respondTo @destination, (message, msgHandler) =>
            msgHandler.nack(@error)
          .then -> done()

        it 'responds with error', (done) ->
          @callback = (error) =>
            error.should.eql(@error)
            done()
          @subject()

    context '#deliverWithResponseAndOptions', ->
      beforeEach ->
        @destination = 'response-test'
        @subject = =>
          @request.deliverWithResponseAndOptions @destination, @message, @options, @callback

      context 'when message was acked', ->
        before -> @message = test: 'data'
        beforeEach (done) ->
          @request.respondTo @destination, (message, msgHandler) =>
            msgHandler.ack(@message)
          .then -> done()

        it 'returns response', (done) ->
          @callback = (message) =>
            message.should.eql(@message)
            done()
          @subject()

      context 'when message was nacked', ->
        before -> @error = test: 'data'
        beforeEach (done) ->
          @request.respondTo @destination, (message, msgHandler) =>
            msgHandler.nack(@error)
          .then -> done()

        it 'returns error', (done) ->
          @callback = (message) =>
            message.error.should.eql(@error)
            done()
          @subject()
