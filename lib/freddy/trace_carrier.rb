# frozen_string_literal: true

class Freddy
  # Carrier for rabbitmq following OpenTracing API
  # See https://github.com/opentracing/opentracing-ruby/blob/master/lib/opentracing/carrier.rb
  class TraceCarrier
    def initialize(properties)
      @properties = properties
    end

    def [](key)
      @properties.headers && @properties.headers["x-trace-#{key}"]
    end

    def []=(key, value)
      @properties[:headers] ||= {}
      @properties[:headers]["x-trace-#{key}"] = value
    end

    def each(&block)
      (@properties.headers || {})
        .select { |key, _| key =~ /^x-trace/ }
        .transform_keys { |key| key.sub(/x-trace-/, '') }
        .each(&block)
    end
  end
end
