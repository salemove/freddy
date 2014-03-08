MessageHandler = require '../lib/nodelib/message_handler'
should = require 'should'
TestHelper = (require './test_helper')

describe 'MessageHandler', ->

  before -> @properties = prop: 'value'

  beforeEach ->
    @messageHandler = new MessageHandler TestHelper.logger('warn'), @properties

  it 'keeps properties', ->
    @messageHandler.properties.should.eql(@properties)

  it 'has promise for checking for reponse', ->
    @messageHandler.whenResponded.should.be.ok

  context 'when acked', ->
    before -> @response = my: 'resp'
    beforeEach -> @messageHandler.ack(@response)

    it 'resolves response promise with the response', (done) ->
      @messageHandler.whenResponded.then (response) =>
        response.should.eql(@response)
        done()

  context 'when nacked', ->

    context 'with error message', ->
      before -> @error = 'bad'
      beforeEach -> @messageHandler.nack(@error)

      it 'resolves response promise with error', (done) ->
        @messageHandler.whenResponded.then (->), (error) =>
          error.should.eql(@error)
          done()

    context 'without error message', ->
      before -> @error = "Message was nacked"
      beforeEach -> @messageHandler.nack()
      it "resolves response with error #{@error}", (done) ->
        @messageHandler.whenResponded.then (->), (error) =>
          error.should.eql(@error)
          done()
