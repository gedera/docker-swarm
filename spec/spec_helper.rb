# frozen_string_literal: true

require "docker_swarm"
require "rspec"
require "json"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.before(:suite) do
    DockerSwarm.configure do |swarm_config|
      swarm_config.socket_path = "unix:///tmp/docker.sock"
      swarm_config.logger = Logger.new("/dev/null")
    end
  end
end
