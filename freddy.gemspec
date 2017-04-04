# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  if RUBY_PLATFORM == 'java'
    spec.name          = "freddy-jruby"
  else
    spec.name          = "freddy"
  end
  spec.version       = '1.3.0'
  spec.authors       = ["Salemove TechMovers"]
  spec.email         = ["techmovers@salemove.com"]
  spec.description   = %q{Messaging API}
  spec.summary       = %q{API for inter-application messaging supporting acknowledgements and request-response}
  spec.license       = "Private"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"

  if RUBY_PLATFORM == 'java'
    spec.add_dependency 'march_hare', '~> 2.12.0'
    spec.add_dependency 'symbolizer'
  else
    spec.add_dependency "bunny", "~> 2.6"
    spec.add_dependency "oj", "~> 2.13"
  end

  spec.add_dependency "thread", "~> 0.1"
  spec.add_dependency "opentracing", "~> 0.3"
end
