# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::LogHelper do
  describe ".format_kv" do
    it "filters password, token, secret, auth, api_key, Data" do
      out = described_class.format_kv(
        password: "p", token: "t", secret: "s", auth: "a",
        api_key: "k", Data: "d"
      )
      expect(out).to eq("password=[FILTERED] token=[FILTERED] secret=[FILTERED] auth=[FILTERED] api_key=[FILTERED] Data=[FILTERED]")
    end

    it "does not filter keys that merely contain 'data' (metadata, database)" do
      out = described_class.format_kv(metadata: { foo: 1 }, database: "swarm")
      expect(out).not_to include("[FILTERED]")
    end

    it "filters keys regardless of casing" do
      out = described_class.format_kv(Password: "x", AUTH: "y")
      expect(out).to eq("Password=[FILTERED] AUTH=[FILTERED]")
    end

    it "swallows formatting errors and returns logging_error event" do
      bad = Object.new.tap { |o| o.define_singleton_method(:map) { raise "boom" } }
      expect(described_class.format_kv(bad)).to eq("event=logging_error")
    end

    # El secreto puede viajar anidado en headers; la redacción debe ser recursiva.
    it "filtra un header sensible anidado (X-Registry-Auth)" do
      out = described_class.format_kv(headers: { "X-Registry-Auth" => "super-secret-token" })
      expect(out).not_to include("super-secret-token")
      expect(out).to include("[FILTERED]")
    end

    it "filtra Authorization anidado, case-insensitive" do
      out = described_class.format_kv(options: { "authorization" => "Bearer x" })
      expect(out).not_to include("Bearer x")
    end
  end

  describe ".sanitize" do
    it "redacta a cualquier profundidad sin tocar claves no sensibles" do
      result = described_class.sanitize(
        method: :post,
        headers: { "X-Registry-Auth" => "cred", "Content-Type" => "application/json" }
      )
      expect(result[:method]).to eq(:post)
      expect(result[:headers]["X-Registry-Auth"]).to eq("[FILTERED]")
      expect(result[:headers]["Content-Type"]).to eq("application/json")
    end

    it "recorre arrays de hashes" do
      result = described_class.sanitize(items: [ { token: "a" }, { name: "ok" } ])
      expect(result[:items][0][:token]).to eq("[FILTERED]")
      expect(result[:items][1][:name]).to eq("ok")
    end

    it "no muta la entrada (la credencial real que va a Excon queda intacta)" do
      original = { headers: { "X-Registry-Auth" => "cred" } }
      described_class.sanitize(original)
      expect(original[:headers]["X-Registry-Auth"]).to eq("cred")
    end

    # El `Env` de un ContainerSpec es un ARRAY DE STRINGS `"CLAVE=VALOR"`: el
    # nombre del secreto vive DENTRO del elemento, no como clave de hash. Antes
    # de esto, `Env` no matcheaba SENSITIVE_KEYS, sus elementos caían al `else`
    # y el valor se logueaba entero en `request_success`.
    context "con la forma real del body de services/create" do
      let(:body) do
        {
          "Name" => "svc",
          "TaskTemplate" => {
            "ContainerSpec" => {
              "Image" => "busybox:1.37",
              "Env" => [
                "SECRET_KEY_BASE=deadbeefcafe123",
                "DB_PASSWORD=hunter2",
                "RAILS_LOG_LEVEL=info",
                "RABBIT_PASS_FILE=/run/secrets/rabbit_password"
              ]
            }
          }
        }
      end

      subject(:env) { described_class.sanitize(body)["TaskTemplate"]["ContainerSpec"]["Env"] }

      it "redacta el valor de las claves sensibles conservando el nombre" do
        expect(env).to include("SECRET_KEY_BASE=[FILTERED]", "DB_PASSWORD=[FILTERED]")
      end

      it "no deja pasar ningún valor sensible" do
        expect(env.join(" ")).not_to include("deadbeefcafe123", "hunter2")
      end

      it "deja intactas las env no sensibles" do
        expect(env).to include("RAILS_LOG_LEVEL=info")
      end

      it "no toca el resto del spec" do
        result = described_class.sanitize(body)
        expect(result["Name"]).to eq("svc")
        expect(result["TaskTemplate"]["ContainerSpec"]["Image"]).to eq("busybox:1.37")
      end

      it "no muta el array original (el spec real que va a Docker queda intacto)" do
        described_class.sanitize(body)
        expect(body["TaskTemplate"]["ContainerSpec"]["Env"]).to include("SECRET_KEY_BASE=deadbeefcafe123")
      end
    end

    describe "redacción de strings CLAVE=VALOR" do
      it "no parte en un `=` que pertenece al valor (base64, URLs)" do
        expect(described_class.sanitize("API_KEY=YWJjPT09")).to eq("API_KEY=[FILTERED]")
      end

      it "cubre un valor multilínea (una clave PEM por env)" do
        pem = "SECRET_KEY=-----BEGIN PRIVATE KEY-----\nMIIabc\n-----END PRIVATE KEY-----"
        expect(described_class.sanitize(pem)).to eq("SECRET_KEY=[FILTERED]")
      end

      # Documenta un hueco REAL de SENSITIVE_KEYS, no del mecanismo de este fix:
      # `private_key` no está en la lista, así que un PEM pasado con ese nombre
      # sigue saliendo en claro. Ampliar la lista se trata aparte, porque cambia
      # el comportamiento de redacción de todos los consumidores.
      it "NO cubre claves ausentes de SENSITIVE_KEYS — hueco conocido" do
        expect(described_class.sanitize("PRIVATE_KEY=abc")).to eq("PRIVATE_KEY=abc")
      end

      it "deja intacto un string sin forma CLAVE=VALOR" do
        expect(described_class.sanitize("connection refused")).to eq("connection refused")
      end

      it "deja intacto un string cuya clave no es sensible" do
        expect(described_class.sanitize("PATH=/usr/bin")).to eq("PATH=/usr/bin")
      end

      it "deja intacto un mensaje de error que contiene un `=` pero no una clave sensible" do
        expect(described_class.sanitize("version=1625722 out of sequence")).to eq("version=1625722 out of sequence")
      end
    end
  end
end
