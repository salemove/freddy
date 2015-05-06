class Freddy
  class Delivery
    attr_reader :info, :properties

    def initialize(info, properties)
      @info = info
      @properties = properties
    end
  end
end
