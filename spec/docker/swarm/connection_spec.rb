# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Connection do
  let(:logger) { instance_double(Logger, level: Logger::INFO) }
  let(:socket_path) { "unix:///var/run/docker.sock" }
  let(:connection) { described_class.new(socket_path, logger) }
  let(:excon_double) { instance_double(Excon::Connection) }
  let(:response_double) { instance_double(Excon::Response, status: 200, body: "{}") }

  before do
    allow(Excon).to receive(:new).and_return(excon_double)
    allow(excon_double).to receive(:request).and_return(response_double)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:debug)
  end

  describe "#request" do
    it "logs success events in KV format" do
      expect(logger).to receive(:info).with(/component=docker_swarm.connection event=request_success source=http/)
      connection.request(method: :get, path: "/info")
    end

    it "marks GET requests as idempotent with retries" do
      expect(excon_double).to receive(:request).with(hash_including(idempotent: true, retries: 3))
      connection.request(method: :get, path: "/info")
    end

    it "does not retry POST requests to avoid duplicate side-effects" do
      expect(excon_double).to receive(:request).with(hash_including(idempotent: false, retries: 0))
      connection.request(method: :post, path: "/services/create", body: { Name: "x" })
    end

    it "does not retry DELETE-like writes via PATCH" do
      expect(excon_double).to receive(:request).with(hash_including(idempotent: false, retries: 0))
      connection.request(method: :patch, path: "/whatever")
    end

    it "masks secrets in logs" do
      expect(logger).to receive(:info).with(/password=\[FILTERED\]/)
      connection.request(method: :post, path: "/auth", password: "secret123")
    end

    # El header con la credencial debe llegar a Excon...
    it "forwardea el header X-Registry-Auth al cliente Excon" do
      expect(excon_double).to receive(:request).with(
        hash_including(headers: { "X-Registry-Auth" => "opaque-cred" })
      )
      connection.request(method: :post, path: "/services/create",
                         headers: { "X-Registry-Auth" => "opaque-cred" })
    end

    # ...pero NUNCA aparecer en los logs (success ni failure).
    it "redacta X-Registry-Auth en el log de éxito" do
      expect(logger).to receive(:info) do |msg|
        expect(msg).to include("[FILTERED]")
        expect(msg).not_to include("opaque-cred")
      end
      connection.request(method: :post, path: "/services/create",
                         headers: { "X-Registry-Auth" => "opaque-cred" })
    end

    it "redacta X-Registry-Auth en el log de fallo" do
      allow(excon_double).to receive(:request).and_raise(Excon::Error::Socket.new(Exception.new("fail")))
      expect(logger).to receive(:error) do |msg|
        expect(msg).not_to include("opaque-cred")
      end
      expect do
        connection.request(method: :post, path: "/services/create",
                           headers: { "X-Registry-Auth" => "opaque-cred" })
      end.to raise_error(DockerSwarm::Error::Communication)
    end

    it "includes duration_s in logs" do
      expect(logger).to receive(:info).with(/duration_s=\d+/)
      connection.request(method: :get, path: "/info")
    end

    # El cliente Excon NO debe recibir debug_* ni logger — su instrumentor
    # filtraría headers de auth custom (X-Registry-Auth). El logging seguro es el nuestro.
    it "crea el cliente Excon sin habilitar su debug ni pasarle el logger" do
      expect(Excon).to receive(:new) do |_url, opts|
        expect(opts).not_to have_key(:debug_request)
        expect(opts).not_to have_key(:debug_response)
        expect(opts).not_to have_key(:logger)
        excon_double
      end
      connection.request(method: :get, path: "/info")
    end

    context "when a request fails" do
      it "logs failure events" do
        allow(excon_double).to receive(:request).and_raise(Excon::Error::Socket.new(Exception.new("fail")))

        expect(logger).to receive(:error).with(/event=request_failure/)
        expect { connection.request(method: :get, path: "/fail") }.to raise_error(DockerSwarm::Error::Communication)
      end

      it "unwraps DockerSwarm errors" do
        # Simulamos un error de DockerSwarm envuelto por Excon
        ds_error = DockerSwarm::Error::Conflict.new("already exists")
        excon_error = Excon::Error::Socket.new(ds_error)

        # Inyectamos la causa manualmente si es necesario (en tests a veces no se propaga igual)
        allow(excon_error).to receive(:cause).and_return(ds_error)
        allow(excon_double).to receive(:request).and_raise(excon_error)

        expect(logger).to receive(:error).with(/error=DockerSwarm::Error::Conflict/)
        expect { connection.request(method: :get, path: "/fail") }.to raise_error(DockerSwarm::Error::Conflict)
      end
    end
  end
end
