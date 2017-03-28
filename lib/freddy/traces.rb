class Freddy
  module Traces
    class Trace
      def self.build
        id = TraceId.generate
        span_id = TraceId.generate
        new(id: id, parent_id: nil, span_id: span_id)
      end

      def self.build_from_existing_trace(id:, parent_id:)
        span_id = TraceId.generate
        new(id: id, parent_id: parent_id, span_id: span_id)
      end

      attr_reader :id, :parent_id, :span_id

      def initialize(id:, parent_id:, span_id:)
        @id = id
        @parent_id = parent_id
        @span_id = span_id
      end

      def to_h
        {id: @id, parent_id: @parent_id, span_id: @span_id}
      end
    end

    module TraceId
      TRACE_ID_UPPER_BOUND = 2 ** 64

      # Generates 64-bit lower-hex encoded ID. This was chosen to be compatible
      # with tracing frameworks like zipkin.
      def self.generate
        rand(TRACE_ID_UPPER_BOUND).to_s(16)
      end
    end

    NO_TRACE = Trace.new(id: nil, parent_id: nil, span_id: nil)
  end
end
