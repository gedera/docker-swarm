# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Node do
  let(:valid_attributes) { { "ID" => "node-123", "Spec" => { "Role" => "manager" }, "Version" => { "Index" => 10 } } }
  let(:node) { described_class.new(valid_attributes) }

  it "includes Updatable concern" do
    expect(node).to be_a(DockerSwarm::Concerns::Updatable)
  end

  it "includes Deletable concern" do
    expect(node).to be_a(DockerSwarm::Concerns::Deletable)
  end

  describe "#update" do
    it "sends update request to Docker" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          action: described_class.routes[:update],
          arguments: { id: "node-123" },
          query_params: { version: 10 },
          payload: { "Role" => "worker" }
        )
      ).and_return(true)

      expect(node.update(Spec: { Role: "worker" })).to be true
    end
  end
end
