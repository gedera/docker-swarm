# frozen_string_literal: true

require_relative "lib/docker_swarm/version"

Gem::Specification.new do |spec|
  spec.name          = "docker-swarm"
  spec.version       = DockerSwarm::VERSION
  spec.authors       = ["Gabriel"]
  spec.email         = ["gabriel@wispro.co"]

  spec.summary       = "A Ruby ORM and API client for Docker Swarm."
  spec.description   = "Simplifies interactions with Docker Swarm through an ActiveModel-compatible ORM and a robust Excon-based API client."
  spec.homepage      = "https://github.com/wispro/docker-swarm"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("{lib,exe}/**/*") + %w[README.md]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "activemodel", ">= 6.0"
  spec.add_dependency "excon", ">= 0.80"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
