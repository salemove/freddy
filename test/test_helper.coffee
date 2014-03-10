winston   = require 'winston'
amqp      = require 'amqplib'
amqpUrl   = "amqp://guest:guest@localhost:5672"

uniqueId = -> id = ""; id += Math.random().toString(36).substr(2) while id.length < 32; id.substr 0, 32

logger = (level = 'debug') ->
  new winston.Logger
    transports: [ new winston.transports.Console level: level, colorize: true, timestamp: true ]

deleteExchange = (connection, exchangeName) ->
  return done() unless connection
  connection.createChannel().then (channel) ->
    channel.deleteExchange(exchangeName)

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
exports.uniqueId = uniqueId