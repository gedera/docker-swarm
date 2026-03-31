# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm System Integration", type: :integration do
  describe DockerSwarm::Swarm do
    it "shows swarm information" do
      info = described_class.show
      expect(info).to be_a(Hash)
      expect(info["ID"]).to be_present
    end
  end

  describe DockerSwarm::System do
    it "returns info" do
      info = described_class.info
      expect(info).to be_a(Hash)
      expect(info["Swarm"]).to be_present
    end

    it "returns version" do
      version = described_class.version
      expect(version).to be_a(Hash)
      expect(version["Version"]).to be_present
    end

    it "responds to _ping (up)" do
      expect(described_class.up).to eq("OK")
    end

    it "returns system disk usage (df)" do
      df = described_class.df
      expect(df).to be_a(Hash)
      expect(df["Volumes"]).to be_present
    end
  end
end
