# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm Security Integration", type: :integration do
  # ---------------------------------------------------------------------------
  # Config
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Config do
    let(:name)   { random_name("test_config") }
    let(:params) { { Spec: { Name: name, Data: Base64.strict_encode64("hello world") } } }

    describe "lifecycle" do
      subject(:config) { described_class.create(params) }

      after { config.destroy rescue nil }

      it "creates a config with an ID" do
        expect(config.ID).to be_present
      end

      it "finds the config by ID after creation" do
        found = described_class.find(config.ID)
        expect(found).to be_present
        expect(found.ID).to eq(config.ID)
      end

      it "destroys the config" do
        expect(config.destroy).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Secret
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Secret do
    let(:name)   { random_name("test_secret") }
    let(:params) { { Spec: { Name: name, Data: Base64.strict_encode64("top secret") } } }

    describe "lifecycle" do
      subject(:secret) { described_class.create(params) }

      after { secret.destroy rescue nil }

      it "creates a secret with an ID" do
        expect(secret.ID).to be_present
      end

      it "finds the secret by ID after creation" do
        found = described_class.find(secret.ID)
        expect(found).to be_present
        expect(found.ID).to eq(secret.ID)
      end

      it "destroys the secret" do
        expect(secret.destroy).to be true
      end
    end
  end
end
