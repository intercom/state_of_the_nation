# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_of_the_nation/version'

Gem::Specification.new do |spec|
  spec.name          = "state_of_the_nation"
  spec.version       = StateOfTheNation::VERSION
  spec.authors       = ["Patrick O'Doherty", "Stephen O'Brien"]
  spec.email         = ["patrick@intercom.io", "stephen@intercom.io"]

  spec.summary       = %q{An easy way to model state changes over time}
  spec.description   = %q{State of the Nation makes modeling object history easy.}
  spec.homepage      = "https://github.com/intercom/state_of_the_nation"
  spec.licenses      = ["Apache License, Version 2.0"]

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "mysql"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "shoulda-matchers"
  spec.add_development_dependency "sqlite3"

  spec.add_runtime_dependency "activesupport", "~> 4.2"
  spec.add_runtime_dependency "activerecord", "~> 4.2"
end
