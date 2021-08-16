# frozen_string_literal: true

require_relative 'adapters/bunny_adapter'

class Freddy
  module Adapters
    def self.determine
      BunnyAdapter
    end
  end
end
