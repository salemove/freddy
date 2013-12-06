# Messaging API for salemove services

----
## Usage

* Inject the appropriate default logger and set up connection parameters:  

        Salemove::Messaging.setup(Logger.new(STDOUT), host: 'localhost', port: 5672, user: 'guest', pass: 'guest')

* Instantiate the messenger facade to produce and consume messages:

        Salemove::Messaging::Messenger.new(use_unique_channel = false, logger = Messaging.logger)

    * if use\_unique\_channel is set to true, then this messenger instance will create and use a new tcp connection

* Produce messages:

        messenger.produce(destination, payload, properties = {})

    * destination is the recepient of the message  
    * payload is the contents of the message
    * additional properties can be passed (shouldn't be necessary under normal circumstances)

* Produce messages expecting explicit acknowledgement

        messenger.produce_with_ack(destination, payload, properties = {}, &callback)

    * callback is called with one argument: a string that contains an error message if 
         * the message couldn't be sent to any consumers or 
         * the consumer negatively acknowledged(nacked) the message or
         * the consumer finished working but didn't positively acknowledge the message

    * callback is called with one argument that is nil if the consumer positively acknowledged the message
    * note that the callback will not be called in the case that there is a consumer who receives the message, but the consumer doesn't finish processing the message or dies in the process.

* Consume messages:

         messenger.consume(destination, &callback)

     * The callback is called with 2 arguments 

       * the parsed message (note that in the message all keys are symbolized)
       * the MessageHandler (described further down)

* Consume messages with acknowledgements

        messenger.consume_with_ack(destination, &callback)

* When consuming messages the MessageHandler is given as the second argument. The following operations are supported:

        msg_handler.consume destination do |payload, msg_handler|
        end


  * acknowledging the message

            msg_handler.ack

  * negatively acknowledging the message

            msg_handler.nack(error)

  * note that the previous two have any effect only when consume_with_ack was used

  * Getting additional properties of the message (shouldn't be necessary under normal circumstances)

            msg_handler.properties  

* When consuming a message a ConsumerHandler is returned. The following operations are supported:

        consumer_handler = messenger.consume ....

  * stop consuming

            consumer_handler.cancel


* Request

        request(destination, payload, options={}, &callback)

  * Callback is called with 2 arguments

    * The parsed response

    * The MessageHandler

* Respond to

        respond_to(destination, &callback)

  * Callback is called with the same 2 arguments as in consume
