q           = require 'q'
Consumer    = require '../lib/nodelib/consumer'
TestHelper  = (require './test_helper')

describe 'Consumer', ->

  before ->
    @topicName = 'consumer-test-topic'

  beforeEach (done) ->
    TestHelper.connect().done (@connection) =>
      @consumer = new Consumer(connection, TestHelper.logger('warn'))
      done()

  after (done) ->
    TestHelper.deleteExchange(@connection, @topicName)
    .then =>
      @connection.close()
    .done ->
      done()

  context '#prepare', ->
    it 'resolves when done', (done) ->
      @consumer.prepare(@topicName).then ->
        done()

  context 'when prepared', ->
    beforeEach (done) ->
      @consumer.prepare(@topicName).then ->
        done()

    context '#consume', ->
      before ->
        @queue = "consumer-test-queue.#{Math.random()*100}"
        @msg = test: 'data'

      afterEach (done) ->
        @connection.createChannel().then (channel) =>
          channel.deleteQueue(@queue)
          done()

      it 'resolves when done', (done) ->
        @consumer.consume(@queue, (->)).then ->
          done()

      it 'receives the correct message', (done) ->
        @consumer.consume @queue, (message) =>
          message.should.eql(@msg)
          done()
        .done =>
          TestHelper.deliver(@connection, @queue, @topicName, @msg)

      context '#responderHandler', ->
        beforeEach (done) ->
          @receivedMessages = 0
          @consumer.consume @queue, =>
            @receivedMessages += 1
          .done (@responderHandler) =>
            done()

        it 'has the queue', ->
          @responderHandler.queue.should.eql(@queue)

        it 'can cancel consuming', (done) ->
          TestHelper.deliver(@connection, @queue, @topicName, @msg)
          q.delay(5)
          .then =>
            @responderHandler.cancel()
          .then =>
            TestHelper.deliver(@connection, @queue, @topicName, @msg)
            q.delay(5)
          .done =>
            @receivedMessages.should.eql(1)
            done()

    context '#tapInto', ->
      before ->
        @queue = "test.mix.best.#{Math.random()*100}"
        @msg = test: 'data'

      afterEach (done) ->
        @responderHandler.cancel().then =>
          done()

      it 'receives messages by * wildcard', (done) ->
        @consumer.tapInto 'test.*.best.#', (message) =>
          message.should.eql(@msg)
          done()
        .done (@responderHandler) =>
          TestHelper.deliver @connection, @queue, @topicName, @msg

      it 'receives messages by # wildcard', (done) ->
        @consumer.tapInto '#.best.#', (message) =>
          message.should.eql(@msg)
          done()
        .done (@responderHandler) =>
          TestHelper.deliver @connection, @queue, @topicName, @msg

      it 'has the destination', (done) ->
        @consumer.tapInto '#', (message, destination) =>
          destination.should.eql(@queue)
          done()
        .done (@responderHandler) =>
          return q(TestHelper.deliver @connection, @queue, @topicName, msg: 'yes')