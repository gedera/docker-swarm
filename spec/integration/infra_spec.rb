# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm Infrastructure Integration", type: :integration do
  # ---------------------------------------------------------------------------
  # Network
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Network do
    let(:name) { random_name("test_net") }

    describe "lifecycle" do
      subject(:network) { described_class.create(Name: name, Driver: "overlay") }

      after { network.destroy rescue nil }

      it "creates an overlay network with an ID" do
        expect(network.ID).to be_present
      end

      it "finds the network by ID" do
        found = described_class.find(network.ID)
        expect(found).to be_present
        expect(found.ID).to eq(network.ID)
      end

      it "lists the network in .all" do
        network_id = network.ID
        expect(described_class.all.map(&:ID)).to include(network_id)
      end

      it "filters by name via .where" do
        network # trigger creation
        result = described_class.where(name: name)
        expect(result.any?).to be true
        expect(result.first.ID).to eq(network.ID)
      end

      it "destroys the network" do
        expect(network.destroy).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Volume
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Volume do
    let(:name) { random_name("test_vol") }

    describe "lifecycle" do
      subject(:volume) { described_class.create(Name: name) }

      after { volume.destroy rescue nil }

      it "creates a volume and returns the Name" do
        expect(volume.Name).to eq(name)
      end

      it "finds the volume by name" do
        volume # ensure creation
        found = described_class.find(name)
        expect(found).to be_present
        expect(found.Name).to eq(name)
      end

      it "lists the volume in .all" do
        volume # trigger creation
        all_names = described_class.all.map(&:Name)
        expect(all_names).to include(name)
      end

      it "destroys the volume" do
        volume # trigger creation
        expect { volume.destroy }.not_to raise_error
      end
    end
  end
end
