# frozen_string_literal: true

require 'zlib'

class Freddy
  class Encoding
    ZLIB_CONTENT_ENCODING = 'zlib'

    def self.compress(data, encoding)
      case encoding
      when ZLIB_CONTENT_ENCODING
        ::Zlib::Deflate.deflate(data)
      else
        data
      end
    end

    def self.uncompress(data, encoding)
      case encoding
      when ZLIB_CONTENT_ENCODING
        ::Zlib::Inflate.inflate(data)
      else
        data
      end
    end
  end
end
