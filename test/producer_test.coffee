Producer = require '../lib/nodelib/producer'
TestHelper = (require './test_helper')

describe 'Producer', ->

  before -> @topicName = 'test-topic'

  beforeEach (done) ->
    TestHelper.connect (@connection) =>
      @producer = new Producer connection, TestHelper.logger('warn')
      done()

  after (done) ->
    TestHelper.deleteExchange(@connection, @topicName)
    .then =>
      @connection.close()
    .then ->
      done()

  context '#prepare', ->
    it 'resolves when done', (done) ->
      @producer.prepare(@topicName).then =>
        done()

  context 'when prepared', ->
    beforeEach (done) ->
      @producer.prepare(@topicName).then =>
        done()

    context '#produce', ->
      it 'produces successfully', ->
        produced = @producer.produce 'test-dest', { test: 'data' }
        produced.should.be.ok
