# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'taskmaster/version'

Gem::Specification.new do |spec|
  spec.name          = "taskmaster"
  spec.version       = Taskmaster::VERSION
  spec.authors       = ["Jonathan Lukens"]
  spec.email         = ["jonathan.lukens@americastestkitchen.com"]
  spec.summary       = %q{Deploy glue for lazy JIRA users.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'hashie'
  spec.add_dependency 'httparty'
  spec.add_dependency 'git'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'pry-byebug'
end
