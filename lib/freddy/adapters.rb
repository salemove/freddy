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
  end
end
