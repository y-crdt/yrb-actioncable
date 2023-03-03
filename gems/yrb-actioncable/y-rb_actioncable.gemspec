# frozen_string_literal: true

require_relative "lib/y/action_cable/version"

Gem::Specification.new do |spec|
  spec.name        = "y-rb_actioncable"
  spec.version     = Y::ActionCable::VERSION
  spec.authors     = ["Hannes Moser"]
  spec.email       = ["box@hannesmoser.at"]
  spec.summary     = "An ActionCable companion for Y.js clients."
  spec.description = "An ActionCable companion for Y.js clients."
  spec.homepage    = "https://github.com/y-crdt/yrb-actioncable"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/y-crdt/yrb-actioncable"
  spec.metadata["documentation_uri"] = "https://y-crdt.github.io/yrb-actioncable/"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE.txt", "Rakefile",
                   "README.md"]

  spec.add_dependency "rails", ">= 7.0.4"
  spec.add_dependency "y-rb", ">= 0.4.5"

  spec.metadata["rubygems_mfa_required"] = "true"
end
