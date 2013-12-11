# Encapsulate publishing. 
# Send every message to the direct queue and the topic exchange.
class Producer
  constructor: (@connection, topicName, @logger) ->
    @topicExchange = @connection.exchange(topicName, {type: 'topic', autoDelete: false})

  produce: (destination, message, options = {}) ->
    throw "Destination must be provided as a string" if (!destination? or !(typeof destination is 'string'))
    throw "Message must be provided" if !message?
    @topicExchange.publish destination, message, options
    @connection.publish destination, message, options

module.exports = Producer