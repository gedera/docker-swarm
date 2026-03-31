# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Network do
  let(:valid_attributes) { { "ID" => "net-123", "Name" => "my-net", "Driver" => "overlay" } }
  let(:network) { described_class.new(valid_attributes) }

  it "includes Creatable concern" do
    expect(network).to be_a(DockerSwarm::Concerns::Creatable)
  end

  it "includes Deletable concern" do
    expect(network).to be_a(DockerSwarm::Concerns::Deletable)
  end

  describe ".create" do
    it "sends a create request to Docker" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:create], payload: { "Name" => "my-net", "Driver" => "overlay" })
      ).and_return({ "ID" => "net-123" })
      
      # For reload
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show], arguments: { id: "net-123" })
      ).and_return(valid_attributes)

      new_net = described_class.create(Name: "my-net", Driver: "overlay")
      expect(new_net.ID).to eq("net-123")
    end
  end
end
