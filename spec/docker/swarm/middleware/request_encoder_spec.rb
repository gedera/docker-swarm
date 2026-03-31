# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Middleware::RequestEncoder do
  let(:stack) { double("stack") }
  let(:middleware) { described_class.new(stack) }

  describe "#request_call" do
    it "serializes JSON by default" do
      env = { body: { foo: "bar" }, headers: {} }
      expect(stack).to receive(:request_call) do |e|
        expect(e[:body]).to eq('{"foo":"bar"}')
        expect(e[:headers]["Content-Type"]).to eq("application/json")
      end
      middleware.request_call(env)
    end

    it "serializes x-www-form-urlencoded correctly" do
      env = { body: { foo: "bar" }, headers: { "Content-Type" => "application/x-www-form-urlencoded" } }
      expect(stack).to receive(:request_call) do |e|
        expect(e[:body]).to eq("foo=bar")
      end
      middleware.request_call(env)
    end

    it "keeps multipart/form-data body as is (Hash)" do
      env = { body: { file: "data" }, headers: { "Content-Type" => "multipart/form-data" } }
      expect(stack).to receive(:request_call) do |e|
        expect(e[:body]).to be_a(Hash)
      end
      middleware.request_call(env)
    end
  end
end
