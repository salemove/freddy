Request = require '../lib/nodelib/request'
Consumer = require '../lib/nodelib/consumer'
Producer = require '../lib/nodelib/producer'
TestHelper = (require './test_helper')

describe 'Request', ->

  before ->
    @topicName = 'test-topic'

  beforeEach (done) ->
    TestHelper.connect (@connection) =>
      @producer = new Producer connection, TestHelper.logger('warn')
      @consumer = new Consumer connection, TestHelper.logger('warn')
      @producer.prepare(@topicName)
      .then =>
        @consumer.prepare(@topicName)
      .then =>
        @request = new Request connection, TestHelper.logger('debug')
        done()

  after (done) ->
    TestHelper.deleteExchange(@connection, @topicName, done)

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

    context 'deliverWithAck', ->
