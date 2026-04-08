# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Service do
  let(:valid_attributes) { { "ID" => "123", "Name" => "my-service", "Spec" => { "Name" => "my-service" }, "Version" => { "Index" => 1 } } }
  let(:service) { described_class.new(valid_attributes) }

  describe "Concerns::Creatable" do
    it "creates a service and reloads its data" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:create], payload: { "Name" => "my-service" })
      ).and_return({ "ID" => "123" })

      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show], arguments: { id: "123" })
      ).and_return(valid_attributes)

      new_service = described_class.create(Name: "my-service", Spec: { Name: "my-service" })
      expect(new_service.ID).to eq("123")
      expect(new_service.Spec).to eq({ "Name" => "my-service" })
    end
  end

  describe "Concerns::Updatable" do
    it "updates a service and sends the correct version index" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          action: described_class.routes[:update],
          arguments: { id: "123" },
          query_params: { version: 1 },
          payload: { "Name" => "new-name" }
        )
      ).and_return({ "ID" => "123" })

      success = service.update(Name: "new-name", Spec: { Name: "new-name" })
      expect(success).to be true
      expect(service.Spec).to eq({ "Name" => "new-name" })
    end
  end

  describe "Concerns::Deletable" do
    it "deletes a service by instance" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:destroy], arguments: { id: "123" })
      ).and_return("")

      expect(service.destroy).to be true
    end

    it "deletes a service by class method" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:destroy], arguments: { id: "123" })
      ).and_return("")

      expect(described_class.destroy("123")).to be true
    end
  end

  describe "#restart" do
    it "increments ForceUpdate and triggers an update" do
      service = described_class.new(
        "ID" => "123",
        "Version" => { "Index" => 5 },
        "Spec" => { "Name" => "my-service", "TaskTemplate" => { "ForceUpdate" => 2 } }
      )

      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          action: described_class.routes[:update],
          arguments: { id: "123" },
          query_params: { version: 5 },
          payload: hash_including("TaskTemplate" => hash_including("ForceUpdate" => 3))
        )
      ).and_return({})

      expect(service.restart).to be true
    end

    it "starts ForceUpdate at 1 when not previously set" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          payload: hash_including("TaskTemplate" => hash_including("ForceUpdate" => 1))
        )
      ).and_return({})

      expect(service.restart).to be true
    end
  end

  describe "#logs" do
    it "fetches logs for the service" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:logs], arguments: { id: "123" })
      ).and_return("log line 1\nlog line 2")

      expect(service.logs).to eq("log line 1\nlog line 2")
    end
  end
end
