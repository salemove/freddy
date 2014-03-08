winston = require 'winston'
FreddySetup = require './nodelib/freddy_setup'

defaultLogger = new winston.Logger
  transports: [ new winston.transports.Console level: 'info', colorize: true, timestamp: true ]

setup = null
connect = (amqpUrl, logger = defaultLogger) ->
  setup = new FreddySetup(logger)
  setup.connect(amqpUrl)

addErrorListener = (listener) ->
  setup.addErrorListener listener if setup

exports.connect = connect
exports.addErrorListener = addErrorListener