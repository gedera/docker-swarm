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

  # Characterization: fija cómo se invocan hoy create/update (formas históricas)
  # ANTES de agregar las opciones registry_auth/registry_auth_from.
  # Estos ejemplos deben seguir verdes tras migrar la firma a `**opts` con extracción:
  # confirman que los keywords sueltos históricos no se rompen (Ruby 3 separa keyword/hash).
  describe "manejo de argumentos (characterization — pin pre-registry_auth)" do
    before do
      allow(DockerSwarm::Api).to receive(:request).and_return({ "ID" => "123" })
      allow(DockerSwarm::Api).to receive(:request)
        .with(hash_including(action: described_class.routes[:show])).and_return(valid_attributes)
    end

    it "acepta un hash braceado posicional" do
      expect { described_class.create({ Name: "web", Spec: { Name: "web" } }) }.not_to raise_error
    end

    it "acepta keywords sueltos históricos (Name:, Spec:)" do
      expect { described_class.create(Name: "web", Spec: { Name: "web" }) }.not_to raise_error
    end

    it "acepta claves string" do
      expect { described_class.create({ "Name" => "web", "Spec" => { "Name" => "web" } }) }.not_to raise_error
    end

    it "update acepta keywords sueltos (la forma que usa #restart)" do
      expect { service.update(Spec: { TaskTemplate: { ForceUpdate: 1 } }) }.not_to raise_error
    end
  end

  describe "registry auth (#19)" do
    describe "en create" do
      before do
        allow(DockerSwarm::Api).to receive(:request)
          .with(hash_including(action: described_class.routes[:show])).and_return(valid_attributes)
      end

      it "manda la credencial en el header X-Registry-Auth" do
        expect(DockerSwarm::Api).to receive(:request).with(
          hash_including(action: described_class.routes[:create], headers: { "X-Registry-Auth" => "b64cred" })
        ).and_return({ "ID" => "123" })

        described_class.create({ Name: "web", Spec: { Name: "web" } }, registry_auth: "b64cred")
      end

      it "no mete la credencial en el payload (no ensucia el Spec)" do
        captured_payload = nil
        allow(DockerSwarm::Api).to receive(:request)
          .with(hash_including(action: described_class.routes[:create])) do |args|
            captured_payload = args[:payload]
            { "ID" => "123" }
          end

        described_class.create({ Name: "web", Spec: { Name: "web" } }, registry_auth: "b64cred")

        expect(captured_payload.to_s).not_to include("b64cred")
      end

      it "no forwardea headers cuando no hay credencial" do
        expect(DockerSwarm::Api).to receive(:request).with(
          hash_including(action: described_class.routes[:create], headers: {})
        ).and_return({ "ID" => "123" })

        described_class.create(Name: "web", Spec: { Name: "web" })
      end
    end

    describe "en update" do
      it "manda la credencial en el header y preserva el version index" do
        expect(DockerSwarm::Api).to receive(:request).with(
          hash_including(
            action: described_class.routes[:update],
            query_params: { version: 1 },
            headers: { "X-Registry-Auth" => "b64cred" }
          )
        ).and_return({})

        expect(service.update({ Name: "new" }, registry_auth: "b64cred")).to be true
      end

      it "manda registry_auth_from como query registryAuthFrom (sin header)" do
        expect(DockerSwarm::Api).to receive(:request).with(
          hash_including(
            action: described_class.routes[:update],
            query_params: { version: 1, registryAuthFrom: "spec" },
            headers: {}
          )
        ).and_return({})

        expect(service.update({ Name: "new" }, registry_auth_from: "spec")).to be true
      end

      it "rechaza registry_auth y registry_auth_from juntos antes del request" do
        expect(DockerSwarm::Api).not_to receive(:request)

        expect { service.update({ Name: "new" }, registry_auth: "b64cred", registry_auth_from: "spec") }
          .to raise_error(ArgumentError, /mutuamente excluyentes/)
      end

      it "rechaza un registry_auth_from inválido antes del request" do
        expect(DockerSwarm::Api).not_to receive(:request)

        expect { service.update({ Name: "new" }, registry_auth_from: "latest") }
          .to raise_error(ArgumentError, /inválido/)
      end
    end
  end
end
