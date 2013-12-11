# Messaging API supporting acknowledgements and request-response

[![Code Climate](https://codeclimate.com/repos/52a1f75613d6374c030432d2/badges/f8f96e50aa9f57dfae00/gpa.png)](https://codeclimate.com/repos/52a1f75613d6374c030432d2/feed)

## Usage

### Ruby

#### Setup

* Inject the appropriate default logger and set up connection parameters:  

```ruby
Freddy.setup(Logger.new(STDOUT), host: 'localhost', port: 5672, user: 'guest', pass: 'guest')
```

* Use Freddy to deliver and respond to messages:

```ruby
freddy = Freddy.new(logger = Freddy.logger)
```
    * by default the Freddy instance will reuse connections and queues for messaging, if you want to use a distinct tcp connection, response queue and timeout checking thread, then use 
```ruby
freddy.use_distinct_connection
```

#### Delivering messages

* Simply deliver a message:
```ruby 
freddy.deliver(destination, message)
```
    * destination is the recipient of the message  
    * message is the contents of the message

* Deliver a message expecting explicit acknowledgement
```ruby
freddy.deliver_with_ack(destination, message, timeout_seconds = 3) do |error|
```

  * If timeout_seconds pass without a response from the responder, then the callback is called with a timeout error.

  * callback is called with one argument: a string that contains an error message if 
    * the message couldn't be sent to any responders or 
    * the responder negatively acknowledged(nacked) the message or 
    * the responder finished working but didn't positively acknowledge the message

  * callback is called with one argument that is nil if the responder positively acknowledged the message
  * note that the callback will not be called in the case that there is a responder who receives the message, but the responder doesn't finish processing the message or dies in the process.

* Deliver expecting a response
```ruby
freddy.deliver_with_response(destination, message, timeout_seconds = 3) do |response, msg_handler|
```

  * If `timeout_seconds pass` without a response from the responder then the callback is called with the hash 
```ruby
{ error: 'Timed out waiting for response' }
```

  * Callback is called with 2 arguments

    * The parsed response

    * The `MessageHandler`(described further down)

#### Responding to messages

* Respond to messages while not blocking the current thread:  
```ruby
freddy.respond_to destination do |message, msg_handler|
```
* Respond to message and block the thread 
```ruby
freddy.respond_to_and_block destination do |message, msg_handler| 
```

* The callback is called with 2 arguments 

  * the parsed message (note that in the message all keys are symbolized)
  * the `MessageHandler` (described further down)

#### The MessageHandler

When responding to messages the MessageHandler is given as the second argument. 
```ruby 
freddy.respond_to destination do |message, msg_handler|
```

The following operations are supported:

  * acknowledging the message
```ruby 
msg_handler.ack(response = nil)
```

    * when the message was produced with `produce_with_response`, then the response is sent to the original producer

    * when the message was produced with `produce_with_ack`, then only a positive acknowledgement is sent, the provided response is dicarded

  * negatively acknowledging the message
```ruby
msg_handler.nack(error = "Couldn't process message")
```

    * when the message was produced with `produce_with_response`, then the following hash is sent to the original producer
```ruby
{ error: error }
```

    * when the message was produced with `produce_with_ack`, then the error (e.g negative acknowledgement) is sent to the original producer 

  * Getting additional properties of the message (shouldn't be necessary under normal circumstances)
```ruby
msg_handler.properties
```

#### Tapping into messages
When it's necessary to receive messages but not consume them, consider tapping.  

```ruby
freddy.tap destination, &callback do |message|
```

* Note that it is not possible to acknowledge or respond to message while tapping.
* When tapping the following wildcards are supported:
  * `#` matching 0 or more words
  * `*` matching exactly one word

Examples:

```ruby
freddy.tap "i.#.free"
```  

receives messages that are delivered to `"i.want.to.break.free"`

```ruby
freddy.tap "somebody.*.love"
```

receives messages that are delivered to `somebody.to.love` but doesn't receive messages delivered to `someboy.not.to.love`

It is also possible to use the blocking version of tap:

```ruby
freddy.tap_and_block destination, &callback do |message|
```

#### The ResponderHandler

When responding to a message or tapping the ResponderHandler is returned. 
```ruby
responder_handler = freddy.respond_to ....
```

The following operations are supported:

  * stop responding
```ruby
responder_handler.cancel
```

  * join the current thread to the responder thread
```ruby
responder_handler.join
```

***

### Node.js

#### Setup
```coffee
freddy = new Freddy amqpUrl
```

* amqpUrl defines the connection e.g `'amqp://guest:guest@localhost:5672'`

* the message 'ready' is emitted when freddy is ready to deliver and respond to message

#### Delivering messages  
```coffee
freddy.deliver destination, message

freddy.deliverWithAck destination, message, callback

freddy.deliverWithResponse destination, message, callback
```

* The default timeout is 3 seconds, to use a custom timeout use  

```coffee
freddy.withTimeout(myTimeoutInSeconds).deliverWithAck...

freddy.withTimeout(myTimeoutInSeconds).deliverWithResponse...
```

#### Responding to messages  
```coffee
freddy.respondTo destination, callback
```

* Sometimes it might be useful to know when the queue has been created for the responder. For that the 'ready' is emitted on the responderHandler.  

```coffee
responderHandler = freddy.respondTo destination, callback
responderHandler.on 'ready', () =>
  freddy.deliver destination, {easy: 'come'}
```

#### The MessageHandler  
No differences to ruby spec

#### Tapping into messages
No differences to ruby spec, except blocking variant is not provided for obvious reasons.

#### The ResponderHandler  

* When cancelling the responder `cancelled` is emitted on the responderHandler when the responder was successfully cancelled. After that the responder will not receive any new messages. 

```coffee
responderHandler = freddy.respondTo destination, () =>
responderHandler.cancel()
responderHandler.on 'cancelled', () =>
  freddy.deliver destination, {easy: 'go'} #will not be received
```
* The join method is not provided for obvious reasons.

## Development

* Use RSpec and mocha, make sure the tests pass.  
* Don't leak underlying messaging protocol internals.