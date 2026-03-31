# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Configuration do
  it "has default values" do
    config = described_class.new
    expect(config.socket_path).to eq("unix:///var/run/docker.sock")
    expect(config.log_level).to eq(Logger::INFO)
    expect(config.read_timeout).to eq(60)
    expect(config.max_retries).to eq(3)
  end

  it "allows updating values" do
    config = described_class.new
    config.socket_path = "http://localhost:2375"
    config.read_timeout = 30
    expect(config.socket_path).to eq("http://localhost:2375")
    expect(config.read_timeout).to eq(30)
  end
end
