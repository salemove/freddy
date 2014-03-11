Freddy      = require '../lib/freddy'
TestHelper  = (require './test_helper')
q           = require 'q'

describe 'Freddy', ->
  before -> @msg = test: 'data'

  it 'exists', ->
    Freddy.should.exist

  context 'with correct amqp url', ->
    it 'can connect to amqp', (done) ->
      Freddy.connect(TestHelper.amqpUrl, TestHelper.logger('warn')).done =>
        done()
      , =>
        done Error("Connection should have succeeded, but failed")

  context 'with incorrect amqp url', ->
    it 'cannot connect', (done) ->
      Freddy.connect('amqp://wrong:wrong@localhost:9000', TestHelper.logger('warn')).done (@freddy) ->
        done(Error("Connection should have failed, but succeed"))
      , =>
        done()

  context 'when connected', ->
    beforeEach (done) ->
      @randomDest = TestHelper.uniqueId()
      Freddy.connect('amqp://guest:guest@localhost:5672', TestHelper.logger('warn')).done (@freddy) =>
        done()
      , (err) ->
        done(err)

    afterEach (done) ->
      @freddy.shutdown().done ->
        done()

    it 'can produce messages', ->
      @freddy.deliver @randomDest, @msg

    describe 'when responding to messages', ->

      it 'catches errors', (done) ->
        myError = new Error('catch me')
        Freddy.addErrorListener (err) ->
          err.should.eql(myError)
          done()

        @freddy.respondTo @randomDest, (message, msgHandler) ->
          throw myError
        .done =>
          @freddy.deliver @randomDest, {}

    describe 'with messages that need acknowledgement', ->
      it 'can produce', ->
        @freddy.deliverWithAck @randomDest, @msg, (->)

    describe 'with messages that need response', ->
      it 'can produce', ->
        @freddy.deliverWithResponse @randomDest, @msg, (->)

    describe 'when tapping', ->
      it "doesn't consume message", (done) ->
        tapPromise = q.defer()
        respondPromise = q.defer()
        @freddy.tapInto @randomDest, =>
          tapPromise.resolve()
        .then =>
          @freddy.respondTo @randomDest, =>
            respondPromise.resolve()
        .done =>
          q.all([tapPromise, respondPromise]).then ->
            done()
          @freddy.deliver @randomDest, @msg