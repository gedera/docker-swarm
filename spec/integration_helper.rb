# frozen_string_literal: true

require "docker_swarm"
require "rspec"
require "json"
require "securerandom"
require "base64"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    DockerSwarm.configure do |swarm_config|
      # Usar el default de la gema o permitir override por ENV
      swarm_config.socket_path = ENV.fetch("DOCKER_URL", "unix:///var/run/docker.sock")
      swarm_config.logger = Logger.new("/dev/null")
    end
  end

  def random_name(prefix)
    "#{prefix}_#{SecureRandom.hex(4)}"
  end
end
