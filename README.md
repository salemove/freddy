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

## Request Tracing

Freddy supports [OpenTracing API|https://github.com/opentracing/opentracing-ruby]. You must set a global tracer which then freddy will use:
```ruby
OpenTracing.global_tracing = MyTracerImplementation.new(...)
```

Current trace can be accessed through a thread-local variable `OpenTracing.active_span`. Calling `deliver` or `deliver_with_response` will pass trace context to down-stream services.

See [opentracing-ruby](https://github.com/opentracing/opentracing-ruby) for more information.

## Notes about concurrency

*freddy* uses a thread pool to run concurrent responders. The thread pool is unique for each *tap_into* and *respond_to* responder. Thread pool size can be configured by passing the configuration option *max_concurrency*. Its default value is 4. e.g. If your application has 2 *respond_to* responders and 1 *tap_into* responder with *max_concurrency* set to 3 then your application may process up to 9 messages in parallel.


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
