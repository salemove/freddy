# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "freddy"
  spec.version       = '0.3.7'
  spec.authors       = ["Urmas Talimaa"]
  spec.email         = ["urmas.talimaa@gmail.com"]
  spec.description   = %q{Messaging API}
  spec.summary       = %q{API for inter-application messaging supporting acknowledgements and request-response}
  spec.license       = "Private"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "bunny", "1.6.3"
  spec.add_dependency "symbolizer"
  spec.add_dependency "hamster", "~> 1.0.1.pre.rc3"
end
