# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  if RUBY_PLATFORM == 'java'
    spec.name          = "freddy-jruby"
  else
    spec.name          = "freddy"
  end
  spec.version       = '0.4.7'
  spec.authors       = ["Urmas Talimaa"]
  spec.email         = ["urmas.talimaa@gmail.com"]
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
    spec.add_dependency "bunny", "2.2.0"
    spec.add_dependency "oj", "~> 2.13"
  end

  spec.add_dependency "hamster", "~> 1.0.1.pre.rc3"
  spec.add_dependency "thread", "~> 0.2"
end
