# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "salemove-messaging"
  spec.version       = '0.0.1'
  spec.authors       = ["Urmas Talimaa"]
  spec.email         = ["urmas.talimaa@gmail.com"]
  spec.description   = %q{Salemove messaging API}
  spec.summary       = %q{API for inter-application messaging for salemove applications and services}
  spec.homepage      = "http://app.salemove.com"
  spec.license       = "Private"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "bunny", "~> 1.0"
end
