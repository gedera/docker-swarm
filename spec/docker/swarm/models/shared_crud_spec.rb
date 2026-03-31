# frozen_string_literal: true

require "spec_helper"

RSpec.shared_examples "a crud resource" do |resource_class, resource_name, valid_attrs|
  let(:id) { "test-id-123" }
  let(:attributes) { { "ID" => id }.merge(valid_attrs.transform_keys(&:to_s)) }
  let(:instance) { resource_class.new(attributes) }

  describe "Concerns::Creatable" do
    it "creates a #{resource_name} and reloads data" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: resource_class.routes[:create], payload: instance.payload_for_docker)
      ).and_return({ "ID" => id })

      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: resource_class.routes[:show], arguments: { id: id })
      ).and_return(attributes)

      new_resource = resource_class.create(valid_attrs)
      expect(new_resource.ID).to eq(id)
    end
  end

  describe "Concerns::Deletable" do
    it "deletes the #{resource_name} instance" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: resource_class.routes[:destroy], arguments: { id: id })
      ).and_return(true)

      expect(instance.destroy).to be true
    end

    it "deletes by ID via class method" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: resource_class.routes[:destroy], arguments: { id: id })
      ).and_return(true)

      expect(resource_class.destroy(id)).to be true
    end
  end

  describe ".all" do
    it "fetches all #{resource_name.pluralize}" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: resource_class.routes[:index])
      ).and_return([ attributes ])

      resources = resource_class.all
      expect(resources.first).to be_a(resource_class)
      expect(resources.first.ID).to eq(id)
    end
  end
end

RSpec.describe "Shared CRUD Models" do
  describe DockerSwarm::Secret do
    it_behaves_like "a crud resource", described_class, "secret", { Spec: { Name: "my-secret", Data: "YmFzZTY0" } }
  end

  describe DockerSwarm::Config do
    it_behaves_like "a crud resource", described_class, "config", { Spec: { Name: "my-config", Data: "YmFzZTY0" } }
  end

  describe DockerSwarm::Volume do
    it_behaves_like "a crud resource", described_class, "volume", { Name: "my-volume", Driver: "local" }
  end

  describe DockerSwarm::Image do
    it_behaves_like "a crud resource", described_class, "image", { RepoTags: [ "nginx:latest" ] }
  end
end
