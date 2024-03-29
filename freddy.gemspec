lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'freddy/version'

Gem::Specification.new do |spec|
  spec.name          = 'freddy'
  spec.version       = Freddy::VERSION
  spec.authors       = ['Glia TechMovers']
  spec.email         = ['techmovers@salemove.com']
  spec.description   = 'Messaging API'
  spec.summary       = 'API for inter-application messaging supporting acknowledgements and request-response'
  spec.license       = 'MIT'
  spec.homepage      = 'https://github.com/salemove/freddy'
  spec.required_ruby_version = '>= 2.7'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'

  spec.add_dependency 'bunny', '~> 2.11'
  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'oj', '~> 3.6'
  spec.add_dependency 'opentelemetry-api', '~> 1.0'
  spec.add_dependency 'opentelemetry-semantic_conventions', '~> 1.0'
  spec.add_dependency 'zlib', '~> 1.1'
end
