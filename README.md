# Messaging API supporting acknowledgements and request-response

## Usage

### Setup

* Inject the appropriate logger and set up connection parameters:

```ruby
freddy = Freddy.build(Logger.new(STDOUT), host: 'localhost', port: 5672, user: 'guest', pass: 'guest')
```

### Destinations
Freddy encourages but doesn't enforce the following protocol for destinations:

* For sending messages to services:

```
<service_name>.<method_name>.<anything_else_you_need>.<...>
```

* For reporting errors:

```
<service_name>.<method_name>.'responder'|'producer'.'errors'
```

### Delivering messages

* Simply deliver a message:
```ruby
freddy.deliver(destination, message)
```
    * destination is the recipient of the message
    * message is the contents of the message

* Deliver expecting a response
```ruby
freddy.deliver_with_response(destination, message, timeout: 3, delete_on_timeout: true) do |response, msg_handler|
```

  * If `timeout` seconds pass without a response from the responder then the callback is called with the hash
```ruby
{ error: 'Timed out waiting for response' }
```

  * Callback is called with 2 arguments

    * The parsed response

    * The `MessageHandler`(described further down)

* Synchronous deliver expecting response
```ruby
  response = freddy.deliver_with_response(destination, message, timeout: 3)
```

### Responding to messages

* Respond to messages while not blocking the current thread:
```ruby
freddy.respond_to destination do |message, msg_handler|
```

* The callback is called with 2 arguments

  * the parsed message (note that in the message all keys are symbolized)
  * the `MessageHandler` (described further down)

### The MessageHandler

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

### Tapping into messages
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

### The ResponderHandler

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


### Notes about concurrency

The underlying bunny implementation uses 1 responder thread by default. This means that if there is a time-consuming process or a sleep call in a responder then other responders will not receive messages concurrently.

This is especially devious when using `deliver_with_response` in a responder because `deliver_with_response` creates a new anonymous responder which will not receive the response if the parent responder uses a sleep call.

To resolve this problem *freddy* uses 4 responder threads by default (configurable by `responder_thread_count`). Note that this means that ordered message processing is not guaranteed by default. Read more from <http://rubybunny.info/articles/concurrency.html>.

## Credits

**freddy** was originally written by [Urmas Talimaa] as part of SaleMove development team.

![SaleMove Inc. 2012][SaleMove Logo]

**freddy** is maintained and funded by [SaleMove, Inc].

The names and logos for **SaleMove** are trademarks of SaleMove, Inc.

[Urmas Talimaa]: https://github.com/urmastalimaa?source=c "Urmas"
[SaleMove, Inc]: http://salemove.com/ "SaleMove Website"
[SaleMove Logo]: http://app.salemove.com/assets/logo.png "SaleMove Inc. 2012"
[Apache License]: http://choosealicense.com/licenses/apache/ "Apache License"
