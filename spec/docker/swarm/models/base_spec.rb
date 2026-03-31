# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Base do
  class DummyModel < DockerSwarm::Base
    def self.resource_name
      "services"
    end
  end

  describe "Attribute Mapping" do
    it "maps PascalCase attributes from Docker to Ruby accessors" do
      model = DummyModel.new("ID" => "123", "Spec" => { "Name" => "Test" }, "CreatedAt" => "2023-01-01")

      expect(model.ID).to eq("123")
      expect(model.Spec).to eq({ "Name" => "Test" })
      expect(model.CreatedAt).to eq("2023-01-01")
    end

    it "handles 'Id' as 'ID' for consistency" do
      model = DummyModel.new("Id" => "123")
      expect(model.ID).to eq("123")
    end

    it "defines accessors dynamically when attributes are assigned" do
      model = DummyModel.new
      model.assign_attributes("NewAttribute" => "Value")

      expect(model.NewAttribute).to eq("Value")
      expect(model.respond_to?(:NewAttribute)).to be true
    end
  end

  describe "Dynamic Setters" do
    it "creates a setter when a non-existent method ending in = is called" do
      model = DummyModel.new
      model.CustomProp = "Foo"
      expect(model.CustomProp).to eq("Foo")
    end
  end

  describe "Persistence" do
    it "is persisted if it has an ID" do
      model = DummyModel.new("ID" => "123")
      expect(model.persisted?).to be true
      expect(model.id).to eq("123")
    end

    it "is not persisted if it doesn't have an ID" do
      model = DummyModel.new
      expect(model.persisted?).to be false
    end
  end

  describe ".all" do
    it "fetches all items from the API and maps them to model instances" do
      allow(DockerSwarm::Api).to receive(:request).and_return([ { "ID" => "1" }, { "ID" => "2" } ])

      items = DummyModel.all
      expect(items.size).to eq(2)
      expect(items.first).to be_a(DummyModel)
      expect(items.first.ID).to eq("1")
    end

    it "correctly formats filters for the API" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "name" => [ "test" ] }.to_json })
      ).and_return([])

      DummyModel.all(name: "test")
    end
  end

  describe ".find" do
    it "fetches a single item by ID" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(arguments: { id: "123" })
      ).and_return({ "ID" => "123" })

      model = DummyModel.find("123")
      expect(model.ID).to eq("123")
    end

    it "returns nil if the item is not found" do
      allow(DockerSwarm::Api).to receive(:request).and_raise(DockerSwarm::Errors::NotFound)

      model = DummyModel.find("missing")
      expect(model).to be_nil
    end
  end

  describe "#payload_for_docker" do
    it "removes internal attributes like ID, CreatedAt, etc." do
      model = DummyModel.new("ID" => "123", "CreatedAt" => "...", "Foo" => "Bar")
      payload = model.payload_for_docker
      expect(payload).to eq({ "Foo" => "Bar" })
      expect(payload).not_to have_key("ID")
    end

    it "merges Spec attributes correctly" do
      model = DummyModel.new("Spec" => { "Name" => "test" }, "Other" => "value")
      payload = model.payload_for_docker
      expect(payload).to eq({ "Name" => "test", "Other" => "value" })
    end
  end
end
