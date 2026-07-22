# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::RegistryAuth do
  describe ".resolve" do
    it "manda la credencial al header X-Registry-Auth y deja la query vacía" do
      headers, query = described_class.resolve(registry_auth: "b64cred")

      expect(headers).to eq("X-Registry-Auth" => "b64cred")
      expect(query).to eq({})
    end

    it "manda registry_auth_from a la query registryAuthFrom y deja los headers vacíos" do
      headers, query = described_class.resolve(registry_auth_from: "spec")

      expect(headers).to eq({})
      expect(query).to eq(registryAuthFrom: "spec")
    end

    it "acepta previous-spec como origen válido" do
      _headers, query = described_class.resolve(registry_auth_from: "previous-spec")

      expect(query).to eq(registryAuthFrom: "previous-spec")
    end

    it "devuelve ambos vacíos cuando no viene ninguna opción" do
      expect(described_class.resolve).to eq([ {}, {} ])
    end

    it "rechaza registry_auth y registry_auth_from juntos (mutuamente excluyentes)" do
      expect { described_class.resolve(registry_auth: "b64cred", registry_auth_from: "spec") }
        .to raise_error(ArgumentError, /mutuamente excluyentes/)
    end

    it "rechaza un registry_auth_from fuera del enum soportado por Docker" do
      expect { described_class.resolve(registry_auth_from: "latest") }
        .to raise_error(ArgumentError, /inválido/)
    end
  end
end
