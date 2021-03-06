
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = if RUBY_PLATFORM == 'java'
                'freddy-jruby'
              else
                'freddy'
              end
  spec.version       = '1.7.0'
  spec.authors       = ['Glia TechMovers']
  spec.email         = ['techmovers@salemove.com']
  spec.description   = 'Messaging API'
  spec.summary       = 'API for inter-application messaging supporting acknowledgements and request-response'
  spec.license       = 'MIT'
  spec.homepage      = 'https://github.com/salemove/freddy'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'

  if RUBY_PLATFORM == 'java'
    spec.add_dependency 'march_hare', '~> 2.12.0'
    spec.add_dependency 'symbolizer'
  else
    spec.add_dependency 'bunny', '~> 2.11'
    spec.add_dependency 'oj', '~> 3.6'
  end

  spec.add_dependency 'opentracing', '~> 0.4'
  spec.add_dependency 'thread', '~> 0.1'
end
