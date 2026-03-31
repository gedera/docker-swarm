# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm Containers Integration", type: :integration do
  # ---------------------------------------------------------------------------
  # Image
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Image do
    it "lists images" do
      images = described_class.all
      expect(images).not_to be_empty
      expect(images.first.ID).to be_present
    end

    it "finds an image by ID" do
      image_id = described_class.all.first.ID
      image = described_class.find(image_id)
      expect(image).to be_present
      expect(image.ID).to eq(image_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Container
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Container do
    it "lists all containers" do
      containers = described_class.all
      # Might be empty if no containers are running
      expect(containers).to be_an(Array)
    end

    it "finds a container by ID if any exists" do
      containers = described_class.all
      if containers.any?
        container_id = containers.first.ID
        container = described_class.find(container_id)
        expect(container).to be_present
        expect(container.ID).to eq(container_id)
      else
        skip "No containers available to test find"
      end
    end
  end
end
