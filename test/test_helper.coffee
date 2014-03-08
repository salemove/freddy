winston = require 'winston'
amqp = require 'amqplib'
amqpUrl = "amqp://guest:guest@localhost:5672"

logger = (level = 'debug') ->
  new winston.Logger
    transports: [ new winston.transports.Console level: level, colorize: true, timestamp: true ]

deleteExchange = (connection, exchangeName, done) ->
  return done() unless connection
  connection.createChannel().then (channel) ->
    channel.deleteExchange exchangeName
    done()

connect = (done) ->
  amqp.connect(amqpUrl).then done

deliver = (connection, queue, topicName, message) ->
  connection.createChannel().then (channel) ->
    messageToSend = new Buffer(JSON.stringify(message))
    channel.publish(topicName, queue, messageToSend)
    channel.sendToQueue(queue, messageToSend)
    channel

exports.logger = logger
exports.deleteExchange = deleteExchange
exports.connect = connect
exports.deliver = deliver
exports.amqpUrl = amqpUrl