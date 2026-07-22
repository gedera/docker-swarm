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
  end
end
