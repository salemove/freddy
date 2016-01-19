# Messaging API supporting acknowledgements and request-response

[![Build Status](https://travis-ci.org/salemove/freddy.svg?branch=master)](https://travis-ci.org/salemove/freddy)
[![Code Climate](https://codeclimate.com/github/salemove/freddy/badges/gpa.svg)](https://codeclimate.com/github/salemove/freddy)
[![Test Coverage](https://codeclimate.com/github/salemove/freddy/badges/coverage.svg)](https://codeclimate.com/github/salemove/freddy/coverage)

## Setup

* Inject the appropriate logger and set up connection parameters:

```ruby
logger = Logger.new(STDOUT)
freddy = Freddy.build(logger, host: 'localhost', port: 5672, user: 'guest', pass: 'guest')
```

## Supported message queues

These message queues have been tested and are working with Freddy. Other queues can be added easily:

* [RabbitMQ](https://www.rabbitmq.com/)

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
`deliver_with_response` raises an error if an error is returned. This can be handled by rescuing from `Freddy::InvalidRequestError` and `Freddy::TimeoutError` as:
```ruby
begin
  response = freddy.deliver_with_response 'Q', {}
  # ...
rescue Freddy::InvalidRequestError => e
  e.response # => { error: 'InvalidRequestError', message: 'Some error message' }
rescue Freddy::TimeoutError => e
  e.response # => { error: 'RequestTimeout', message: 'Timed out waiting for response' }
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
responder_handler.shutdown
```


## Notes about concurrency

The underlying bunny implementation uses 1 responder thread by default. This means that if there is a time-consuming process or a sleep call in a responder then other responders will not receive messages concurrently.
To resolve this problem *freddy* uses a thread pool for running concurrent responders.
The thread pool is shared between *tap_into* and *respond_to* callbacks and the default size is 4.
The thread pool size can be configured by passing the configuration option *max_concurrency*.


Note that while it is possible to use *deliver_with_response* inside a *respond_to* block,
it is not possible to use another *respond_to* block inside a different *respond_to* block.


Note also that other configuration options for freddy users
such as pool sizes for DB connections need to match or exceed *max_concurrency*
to avoid running out of resources.

Read more from <http://rubybunny.info/articles/concurrency.html>.

## Credits

**freddy** was originally written by [Urmas Talimaa] as part of SaleMove development team.

![SaleMove Inc. 2012][SaleMove Logo]

**freddy** is maintained and funded by [SaleMove, Inc].

The names and logos for **SaleMove** are trademarks of SaleMove, Inc.

[Urmas Talimaa]: https://github.com/urmastalimaa?source=c "Urmas"
[SaleMove, Inc]: http://salemove.com/ "SaleMove Website"
[SaleMove Logo]: http://app.salemove.com/assets/logo.png "SaleMove Inc. 2012"
[Apache License]: http://choosealicense.com/licenses/apache/ "Apache License"
