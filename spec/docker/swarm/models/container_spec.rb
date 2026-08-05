# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Container do
  let(:valid_attributes) { { "ID" => "container-123", "Names" => [ "/my-container" ] } }
  let(:container) { described_class.new(valid_attributes) }

  describe ".create" do
    let(:created) { { "Id" => "container-123", "Warnings" => [] } }

    it "manda el nombre por query string y lo saca del body" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          action: described_class.routes[:create],
          query_params: { name: "acs-seed-helper" }
        )
      ) do |args|
        expect(args[:payload]).not_to have_key("name")
        expect(args[:payload]).to include("Image" => "mongo:4.4")
        created
      end
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show])
      ).and_return(created)

      container = described_class.create(name: "acs-seed-helper", Image: "mongo:4.4")

      expect(container.ID).to eq("container-123")
    end

    it "no manda query params si no hay nombre" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:create], query_params: {})
      ).and_return(created)
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show])
      ).and_return(created)

      described_class.create(Image: "mongo:4.4")
    end
  end

  describe ".create_query_params" do
    it "declara name" do
      expect(described_class.create_query_params).to eq(%w[name])
    end

    it "no lo declara en los modelos que no lo necesitan" do
      expect(DockerSwarm::Volume.create_query_params).to be_empty
    end
  end

  describe ".index_query_params (regresión #22)" do
    it "NO declara status: en containers es un filtro válido de Docker, no un query param" do
      expect(described_class.index_query_params).not_to include(:status)
    end

    it "sigue mandando status dentro del JSON de filters" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "status" => [ "running" ] }.to_json })
      ).and_return([])

      described_class.where(status: "running")
    end
  end

  describe ".index_query_params (#35)" do
    it "declara los tres query params propios de ContainerList" do
      expect(described_class.index_query_params).to eq(%i[all limit size])
    end

    it "manda since/before como FILTROS, no en la URL" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "since" => [ "abc123" ] }.to_json })
      ).and_return([])

      described_class.where(since: "abc123")
    end

    it "manda size en la URL, no como filtro" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { size: true })
      ).and_return([])

      described_class.where(size: true)
    end

    it "no arrastra force, que no existe en el listado" do
      expect(described_class.index_query_params).not_to include(:force)
    end
  end

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
