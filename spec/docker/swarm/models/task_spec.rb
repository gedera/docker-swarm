# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Task do
  let(:valid_attributes) { { "ID" => "task-123", "ServiceID" => "svc-1" } }
  let(:task) { described_class.new(valid_attributes) }

  it "can be fetched with all" do
    allow(DockerSwarm::Api).to receive(:request).and_return([ valid_attributes ])
    tasks = described_class.all
    expect(tasks.first).to be_a(described_class)
    expect(tasks.first.ID).to eq("task-123")
  end

  describe "#logs" do
    it "fetches logs for the task" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:logs], arguments: { id: "task-123" })
      ).and_return("task logs")

      expect(task.logs).to eq("task logs")
    end
  end
end
