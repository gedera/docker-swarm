# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Container do
  let(:valid_attributes) { { "ID" => "container-123", "Names" => ["/my-container"] } }
  let(:container) { described_class.new(valid_attributes) }

  describe "#start" do
    it "calls the start endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:start], arguments: { id: "container-123" })
      ).and_return(true)
      
      expect(container.start).to be true
    end
  end

  describe "#stop" do
    it "calls the stop endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:stop], arguments: { id: "container-123" })
      ).and_return(true)
      
      expect(container.stop).to be true
    end
  end

  describe "#logs" do
    it "calls the logs endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:logs], arguments: { id: "container-123" })
      ).and_return("container logs")
      
      expect(container.logs).to eq("container logs")
    end
  end
end
