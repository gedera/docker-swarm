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
  end
end
