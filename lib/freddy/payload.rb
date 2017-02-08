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
      PARSE_OPTIONS = { symbol_keys: true }
      DUMP_OPTIONS = { mode: :compat, time_format: :xmlschema, second_precision: 6 }

      def self.parse(payload)
        Oj.strict_load(payload, PARSE_OPTIONS)
      end

      def self.dump(payload)
        Oj.dump(payload, DUMP_OPTIONS)
      end
    end

    class JsonAdapter
      def self.parse(payload)
        # MRI has :symbolize_keys, but JRuby does not. Not adding it at the
        # moment.
        Symbolizer.symbolize(JSON.parse(payload))
      end

      def self.dump(payload)
        JSON.dump(serialize_time_objects(payload))
      end

      def self.serialize_time_objects(object)
        if object.is_a?(Hash)
          object.reduce({}) do |hash, (key, value)|
            hash.merge(key => serialize_time_objects(value))
          end
        elsif object.is_a?(Array)
          object.map(&method(:serialize_time_objects))
        elsif object.is_a?(Time) || object.is_a?(Date)
          object.iso8601
        else
          object
        end
      end
    end
  end
end
