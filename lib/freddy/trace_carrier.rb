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
      Hash[
        (@properties.headers || {})
          .select {|key, _| key =~ /^x-trace/}
          .map {|key, value| [key.sub(/x-trace-/, ''), value]}
      ].each(&block)
    end

    def has_required_fields?
      self['trace-id'] && self['parent-id'] && self['span-id']
    end
  end
end
