# frozen_string_literal: true

class Freddy
  module Adapters
    def self.determine
      if RUBY_PLATFORM == 'java'
        require_relative 'adapters/march_hare_adapter'
        MarchHareAdapter
      else
        require_relative 'adapters/bunny_adapter'
        BunnyAdapter
      end
    end

    module Shared
      class Queue
        def initialize(queue)
          @queue = queue
        end

        def bind(*args)
          @queue.bind(*args)
          self
        end

        def name
          @queue.name
        end

        def message_count
          @queue.message_count
        end
      end
    end
  end
end
