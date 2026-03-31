# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Swarm do
  describe ".show" do
    it "calls the swarm show endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: DockerSwarm::Api::ENDPOINTS[:swarm][:show])
      ).and_return({ "ID" => "swarm-1" })

      expect(described_class.show).to eq({ "ID" => "swarm-1" })
    end
  end
end
