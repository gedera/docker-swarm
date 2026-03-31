# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::System do
  describe ".info" do
    it "calls the info endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: DockerSwarm::Api::ENDPOINTS[:system][:info])
      ).and_return({ "ID" => "node-1" })

      expect(described_class.info).to eq({ "ID" => "node-1" })
    end
  end

  describe ".version" do
    it "calls the version endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: DockerSwarm::Api::ENDPOINTS[:system][:version])
      ).and_return({ "Version" => "20.10" })

      expect(described_class.version).to eq({ "Version" => "20.10" })
    end
  end

  describe ".up" do
    it "calls the _ping endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: DockerSwarm::Api::ENDPOINTS[:system][:up])
      ).and_return("OK")

      expect(described_class.up).to eq("OK")
    end
  end

  describe ".df" do
    it "calls the system/df endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: DockerSwarm::Api::ENDPOINTS[:system][:df])
      ).and_return({ "Volumes" => [] })

      expect(described_class.df).to eq({ "Volumes" => [] })
    end
  end
end
