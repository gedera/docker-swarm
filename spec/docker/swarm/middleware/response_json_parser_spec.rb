# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Middleware::ResponseJSONParser do
  let(:stack) { double("stack") }
  let(:middleware) { described_class.new(stack) }

  describe "#response_call" do
    it "parses JSON hashes with indifferent access" do
      env = { response: { body: '{"ID":"123"}', headers: { "Content-Type" => "application/json" } } }
      expect(stack).to receive(:response_call) do |e|
        expect(e[:response][:body][:ID]).to eq("123")
        expect(e[:response][:body]["ID"]).to eq("123")
      end
      middleware.response_call(env)
    end

    it "parses JSON arrays with deep indifferent access" do
      env = { response: { body: '[{"ID":"123"}]', headers: { "Content-Type" => "application/json" } } }
      expect(stack).to receive(:response_call) do |e|
        expect(e[:response][:body].first[:ID]).to eq("123")
      end
      middleware.response_call(env)
    end
  end
end
