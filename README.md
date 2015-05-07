# Messaging API supporting acknowledgements and request-response

[![Build Status](https://travis-ci.org/salemove/node-freddy.svg?branch=master)](https://travis-ci.org/salemove/node-freddy)
[![Code Climate](https://codeclimate.com/github/salemove/freddy/badges/gpa.svg)](https://codeclimate.com/github/salemove/freddy)

## Setup

* Inject the appropriate logger and set up connection parameters:

```ruby
logger = Logger.new(STDOUT)
freddy = Freddy.build(logger, host: 'localhost', port: 5672, user: 'guest', pass: 'guest')
```

## Delivering messages

### Simple delivery

#### Send and forget
Sends a `message` to the given `destination`. If there is no consumer then the
message stays in the queue until somebody consumes it.
```ruby
  freddy.deliver(destination, message)
```

#### Expiring messages
Sends a `message` to the given `destination`. If nobody consumes the message in
`timeout` seconds then the message is discarded. This is useful for showing
notifications that must happen in a certain timeframe but where we don't really
care if it reached the destination or not.
```ruby
freddy.deliver(destination, message, timeout: 5)
```

### Request delivery
#### Expiring messages
Sends a `message` to the given `destination`. Has a default timeout of 3 and
discards the message from the queue if a response hasn't been returned in that
time.
```ruby
response = freddy.deliver_with_response(destination, message)
```

#### Persistant messages
Sends a `message` to the given `destination`. Keeps the message in the queue if
a timeout occurs.
```ruby
response = freddy.deliver_with_response(destination, message, timeout: 4, delete_on_timeout: false)
```

#### Errors
`deliver_with_response` raises an error if an error is returned. This can be handled by rescuing from `Freddy::ErrorResponse` as:
```ruby
begin
  response = freddy.deliver_with_response 'Q', {}
  # ...
rescue Freddy::ErrorResponse => e
  e.response # => { error: 'Timed out waiting for response' }
```

## Responding to messages
```ruby
freddy.respond_to destination do |message, msg_handler|
  # ...
end
```

The callback is called with 2 arguments
  * the parsed message (note that in the message all keys are symbolized)
  * the `MessageHandler` (described further down)

## The MessageHandler

When responding to messages the MessageHandler is given as the second argument.

The following operations are supported:

  * responding with a successful response
```ruby
msg_handler.success(response = nil)
```

  * responding with an error response
```ruby
msg_handler.error(error: "Couldn't process message")
```

## Tapping into messages
When it's necessary to receive messages but not consume them, consider tapping.

```ruby
freddy.tap_into pattern do |message, destination|
```

* `destination` refers to the destination that the message was sent to
* Note that it is not possible to respond to the message while tapping.
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

## The ResponderHandler

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


## Notes about concurrency

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
