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
      # Ruta exacta proporcionada por el usuario
      swarm_config.socket_path = "/var/run/docker.sock"
      swarm_config.logger = Logger.new("/dev/null")
    end
  end

  def random_name(prefix)
    "#{prefix}_#{SecureRandom.hex(4)}"
  end
end
