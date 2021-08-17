# frozen_string_literal: true

require 'oj'

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
      @json_handler ||= OjAdapter
    end

    class OjAdapter
      PARSE_OPTIONS = { symbol_keys: true }.freeze
      DUMP_OPTIONS = { mode: :custom, time_format: :xmlschema, second_precision: 6 }.freeze

      def self.parse(payload)
        Oj.strict_load(payload, PARSE_OPTIONS)
      end

      def self.dump(payload)
        Oj.dump(payload, DUMP_OPTIONS)
      end
    end
  end
end
