# Messaging API supporting acknowledgements and request-response

[![Build Status](http://ci.salemove.com/buildStatus/icon?job=freddy)](http://ci.salemove.com/job/freddy/)
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

#### Destinations
Freddy encourages but doesn't enforce the following protocol for destinations:

* For sending messages to services:

```
<service_name>.<method_name>.<anything_else_you_need>.<...>
```

* For reporting errors:

```
<service_name>.<method_name>.'responder'|'producer'.'errors'
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

* Synchronous deliver expecting response
```ruby
  response = freddy.deliver_with_response(destination, message, timeout_seconds = 3)
```

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
freddy.tap_into pattern do |message, destination|
```

* `destination` refers to the destination that the message was sent to
* Note that it is not possible to acknowledge or respond to message while tapping.
* When tapping the following wildcards are supported in the `pattern` :
  * `#` matching 0 or more words
  * `*` matching exactly one word

Examples:

```ruby
freddy.tap_into "i.#.free"
```

receives messages that are delivered to `"i.want.to.break.free"`

```ruby
freddy.tap_into "somebody.*.love"
```

receives messages that are delivered to `somebody.to.love` but doesn't receive messages delivered to `someboy.not.to.love`

It is also possible to use the blocking version of `tap_into`:

```ruby
freddy.tap_into_and_block pattern, &callback do |message, destination|
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

  * delete the destination
```ruby
responder_handler.destroy_destination
```

    * Primary use case is in tests to not leave dangling destinations. It deletes the destination even if there are responders for the same destination in other parts of the system. Use with caution in production code.


#### Notes about concurrency

The underlying bunny implementation uses 1 responder thread by default. This means that if there is a time-consuming process or a sleep call in a responder then other responders will not receive messages concurrently.

This is especially devious when using `deliver_with_response` in a responder because `deliver_with_response` creates a new anonymous responder which will not receive the response if the parent responder uses a sleep call.

To resolve this problem *freddy* uses 4 responder threads by default (configurable by `responder_thread_count`). Note that this means that ordered message processing is not guaranteed by default. Read more from <http://rubybunny.info/articles/concurrency.html>.

***

### Node.js

#### Setup
```coffee
Freddy = require 'freddy'
Freddy.addErrorListener(listener)
Freddy.connect('amqp://guest:guest@localhost:5672', logger).then (freddy) ->
  continueWith(freddy)
, (error) ->
  doSthWithError(error)
```

#### Delivering messages
```coffee
freddy.deliver(destination, message, options = {})

freddy.deliverWithAck(destination, message, callback)

freddy.deliverWithResponse(destination, message, callback)
```

* The previous 2 can be used with additional options also:
```coffee
freddy.deliverWithAckAndOptions(destination, message, options, callback)

freddy.deliverWithResponseAndOptions(destination, message, options, callback)
```

  The options include:

  * `timeout`: In seconds, defaults to 3.
  * `suppressLog`: Avoid logging the message contents


#### Responding to messages
```coffee
freddy.respondTo(destination, callback)
```

* `respondTo` returns a promise which resolved with the ResponderHandler

```coffee
freddy.respondTo(destination, callback)
.then (responderHandler) ->
  doSthWith(responderHandler.cancel())
```

#### The MessageHandler
No differences to ruby spec

#### Tapping into messages

```coffee
responderHandler = freddy.tapInto(pattern, callback)
```

No other differences to ruby spec, blocking variant is not provided for obvious reasons.

#### The ResponderHandler

* When cancelling the responder returns a promise, no messages will be received after the promise resolves.

```coffee
freddy.respondTo(destination, (->)).then (responderHandler) ->
  responderHandler.cancel().then ->
    freddy.deliver(destination, easy: 'go') #will not be received
```
* The join method is not provided for obvious reasons.

## Development

* Use RSpec and mocha, make sure the tests pass.
* Don't leak underlying messaging protocol internals.

## Credits

**freddy** was originally written by [Urmas Talimaa] as part of SaleMove development team.

![SaleMove Inc. 2012][SaleMove Logo]

**freddy** is maintained and funded by [SaleMove, Inc].

The names and logos for **SaleMove** are trademarks of SaleMove, Inc.

## License

**freddy** is Copyright © 2013 SaleMove Inc. It is free software, and may be redistributed under the terms specified in the [Apache License].

[Urmas Talimaa]: https://github.com/urmastalimaa?source=c "Urmas"
[SaleMove, Inc]: http://salemove.com/ "SaleMove Website"
[SaleMove Logo]: http://app.salemove.com/assets/logo.png "SaleMove Inc. 2012"
[Apache License]: http://choosealicense.com/licenses/apache/ "Apache License"
