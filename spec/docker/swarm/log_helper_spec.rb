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
  end
end
