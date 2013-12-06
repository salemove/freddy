# Messaging API for salemove services
----

[![Code Climate](https://codeclimate.com/repos/52a1f75613d6374c030432d2/badges/f8f96e50aa9f57dfae00/gpa.png)](https://codeclimate.com/repos/52a1f75613d6374c030432d2/feed)

## Usage

* Inject the appropriate default logger and set up connection parameters:  

        Salemove::Messaging.setup(Logger.new(STDOUT), host: 'localhost', port: 5672, user: 'guest', pass: 'guest')

* Instantiate the messenger facade to produce and respond to messages:

        Salemove::Messaging::Messenger.new(use_unique_channel = false, logger = Messaging.logger)

    * if use\_unique\_channel is set to true, then this messenger instance will create and use a new tcp connection

* Produce messages:

        messenger.produce(destination, payload, properties = {})

    * destination is the recipient of the message  
    * payload is the contents of the message
    * additional properties can be passed (shouldn't be necessary under normal circumstances)

* Produce messages expecting explicit acknowledgement

        messenger.produce_with_ack(destination, payload, properties = {}, &callback)

    * callback is called with one argument: a string that contains an error message if 
         * the message couldn't be sent to any responders or 
         * the responder negatively acknowledged(nacked) the message or
         * the responder finished working but didn't positively acknowledge the message

    * callback is called with one argument that is nil if the responder positively acknowledged the message
    * note that the callback will not be called in the case that there is a responder who receives the message, but the responder doesn't finish processing the message or dies in the process.

* Request

        request(destination, payload, options={}, &callback)

  * Callback is called with 2 arguments

    * The parsed response

    * The MessageHandler

* Respond to messages:

         messenger.respond_to(destination, &callback)

     * The callback is called with 2 arguments 

       * the parsed message (note that in the message all keys are symbolized)
       * the MessageHandler (described further down)

    * The return value of the callback is used for response if the message was produced by a *request* 

* When responding to messages the MessageHandler is given as the second argument. The following operations are supported:

        messenger.respond_to destination do |payload, msg_handler|
        ...


  * acknowledging the message

            msg_handler.ack

  * negatively acknowledging the message

            msg_handler.nack(error)

  * note that the previous two have effect only when *produce\_with\_ack* was used

  * Getting additional properties of the message (shouldn't be necessary under normal circumstances)

            msg_handler.properties  

* When responding to a message a ResponderHandler is returned. The following operations are supported:

        responder_handler = messenger.respond_to ....

  * stop responding

            responder_handler.cancel
