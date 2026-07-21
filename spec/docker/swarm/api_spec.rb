# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Api do
  let(:action) { { method: :get, path: "test/%<id>s" } }
  let(:arguments) { { id: "123" } }
  let(:query_params) { { foo: "bar" } }
  let(:payload) { { key: "value" } }

  describe ".request" do
    it "calls DockerSwarm.request with formatted path and parameters" do
      expect(DockerSwarm).to receive(:request).with(
        method: :get,
        path: "test/123",
        query: query_params,
        body: payload
      ).and_return({ "Status" => "OK" })

      response = described_class.request(
        action: action,
        arguments: arguments,
        query_params: query_params,
        payload: payload
      )

      expect(response).to eq({ "Status" => "OK" })
    end

    # Canal de headers (default vacío = request idéntica a la actual).
    it "no incluye la clave :headers cuando no se pasan (compatibilidad)" do
      expect(DockerSwarm).to receive(:request) do |opts|
        expect(opts).not_to have_key(:headers)
        {}
      end

      described_class.request(action: action, arguments: arguments)
    end

    it "forwardea :headers a DockerSwarm.request cuando se pasan" do
      expect(DockerSwarm).to receive(:request).with(
        hash_including(headers: { "X-Registry-Auth" => "opaque-token" })
      ).and_return({})

      described_class.request(
        action: action,
        arguments: arguments,
        headers: { "X-Registry-Auth" => "opaque-token" }
      )
    end
  end
end
