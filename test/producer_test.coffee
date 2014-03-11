Producer    = require '../lib/nodelib/producer'
TestHelper  = (require './test_helper')

describe 'Producer', ->

  before -> @topicName = 'test-topic'

  beforeEach (done) ->
    TestHelper.connect().done (@connection) =>
      @producer = new Producer connection, TestHelper.logger('warn')
      done()

  after (done) ->
    return done() unless @connection
    TestHelper.deleteExchange(@connection, @topicName)
    .then =>
      @connection.close()
    .done ->
      done()

  context '#prepare', ->
    it 'resolves when done', (done) ->
      @producer.prepare(@topicName).done =>
        done()

  context 'when prepared', ->
    beforeEach (done) ->
      @producer.prepare(@topicName).done =>
        done()

    context '#produce', ->
      it 'produces successfully', ->
        produced = @producer.produce 'test-dest', { test: 'data' }
        produced.should.be.ok
