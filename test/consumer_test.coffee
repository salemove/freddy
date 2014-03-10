Consumer = require '../lib/nodelib/consumer'
TestHelper = (require './test_helper')

describe 'Consumer', ->

  before ->
    @topicName = 'consumer-test-topic'

  beforeEach (done) ->
    TestHelper.connect (@connection) =>
      @consumer = new Consumer(connection, TestHelper.logger('warn'))
      done()

  after (done) ->
    TestHelper.deleteExchange(@connection, @topicName)
    .then =>
      @connection.close()
    .then ->
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
      before -> @queue = "consumer-test-queue.#{Math.random()*100}"

      afterEach (done) ->
        @connection.createChannel().then (channel) =>
          channel.deleteQueue(@queue)
          done()

      it 'resolves when done', (done) ->
        @consumer.consume(@queue, (->)).then ->
          done()

      context '#responderHandler', ->
        beforeEach (done) ->
          @receivedMessages = 0
          @consumer.consume @queue, =>
            @receivedMessages += 1
          .then (@responderHandler) =>
            done()

        it 'has the queue', ->
          @responderHandler.queue.should.eql(@queue)

        it 'can cancel consuming', (done) ->
          @responderHandler.cancel().then =>
            TestHelper.deliver(@connection, @queue, @topicName, msg: 'hello')
          .then =>
            setTimeout =>
              @receivedMessages.should.eql(0)
              done()
            , 5

    context '#tapInto', ->
      before -> @queue = "test.mix.best.#{Math.random()*100}"

      afterEach (done) ->
        @responderHandler.cancel().then =>
          done()

      it 'receives messages by * wildcard', (done) ->
        @consumer.tapInto 'test.*.best.#', =>
          done()
        .then (@responderHandler) =>
          TestHelper.deliver @connection, @queue, @topicName, msg: 'yes'

      it 'receives messages by # wildcard', (done) ->
        @consumer.tapInto '#.best.#', =>
          done()
        .then (@responderHandler) =>
          TestHelper.deliver @connection, @queue, @topicName, msg: 'yes'

