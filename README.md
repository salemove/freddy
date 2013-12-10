# Messaging API supporting acknowledgements and request-response
----

[![Code Climate](https://codeclimate.com/repos/52a1f75613d6374c030432d2/badges/f8f96e50aa9f57dfae00/gpa.png)](https://codeclimate.com/repos/52a1f75613d6374c030432d2/feed)

## Usage

* Inject the appropriate default logger and set up connection parameters:  

        Freddy.setup(Logger.new(STDOUT), host: 'localhost', port: 5672, user: 'guest', pass: 'guest')

* Use Freddy to deliver and respond to messages:

        Freddy.new(use_distinct_connection = false, logger = Freddy.logger)

    * if *use\_distinct\_connection* is set to true, then this Freddy instance will internally use a distinct tcp connection, response queue and timeout checking thread, otherwise global components are reused.

* Deliver messages:

        freddy.deliver(destination, message)

    * destination is the recipient of the message  
    * message is the contents of the message

* Deliver messages expecting explicit acknowledgement

        freddy.deliver_with_ack(destination, message, timeout_seconds = 3) do |error|

  * If timeout_seconds pass without a response from the responder, then the callback is called with a timeout error.

  * callback is called with one argument: a string that contains an error message if 
    * the message couldn't be sent to any responders or 
    * the responder negatively acknowledged(nacked) the message or 
    * the responder finished working but didn't positively acknowledge the message

  * callback is called with one argument that is nil if the responder positively acknowledged the message
  * note that the callback will not be called in the case that there is a responder who receives the message, but the responder doesn't finish processing the message or dies in the process.

* Deliver with response

        freddy.deliver_with_response(destination, message, timeout_seconds = 3) do |response, msg_handler|

  * If timeout_seconds pass without a response from the responder then the callback is called with the hash 

            { error: 'Timed out waiting for response' }

  * Callback is called with 2 arguments

    * The parsed response

    * The MessageHandler(described further down)

* Respond to messages:

         freddy.respond_to destination, block_thread = false do |message, msg_handler|

  * if *block\_thread* is set to true then the thread will block and the handle to the thread is returned 

  * The callback is called with 2 arguments 

    * the parsed message (note that in the message all keys are symbolized)
    * the MessageHandler (described further down)

* When responding to messages the MessageHandler is given as the second argument. The following operations are supported:

        freddy.respond_to destination do |message, msg_handler|

  * acknowledging the message

            msg_handler.ack(response = nil)

    * when the message was produced with *produce\_with\_response*, then the response is sent to the original producer

    * when the message was produced with *produce\_with\_ack*, then only a positive acknowledgement is sent, the provided response is dicarded

  * negatively acknowledging the message

            msg_handler.nack(error = "Couldn't process message")

    * when the message was produced with *produce\_with\_response*, then the following hash is sent to the original producer

                { error: error }

    * when the message was produced with *produce\_with\_ack*, then the error (e.g negative acknowledgement) is sent to the original producer 

  * Getting additional properties of the message (shouldn't be necessary under normal circumstances)

            msg_handler.properties  

* When responding to a message a ResponderHandler is returned. The following operations are supported:

        responder_handler = freddy.respond_to ....

  * stop responding

            responder_handler.cancel
