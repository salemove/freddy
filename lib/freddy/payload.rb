begin
  require 'oj'
rescue LoadError
  require 'symbolizer'
  require 'json'
end

class Freddy
  class Payload
    def self.parse(payload)
      return {} if payload == 'null'

      json_handler.parse(payload)
    end

    def self.dump(payload)
      json_handler.dump(payload)
    end

    def self.json_handler
      @_json_handler ||= defined?(Oj) ? OjAdapter : JsonAdapter
    end

    class OjAdapter
      def self.parse(payload)
        Oj.load(payload, symbol_keys: true)
      end

      def self.dump(payload)
        Oj.dump(payload, mode: :compat)
      end
    end

    class JsonAdapter
      def self.parse(payload)
        # MRI has :symbolize_keys, but JRuby does not. Not adding it at the
        # moment.
        Symbolizer.symbolize(JSON.parse(payload))
      end

      def self.dump(payload)
        JSON.dump(payload)
      end
    end
  end
end
