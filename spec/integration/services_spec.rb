# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm Services Integration", type: :integration do
  # ---------------------------------------------------------------------------
  # Node
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Node do
    it "lists all nodes" do
      nodes = described_class.all
      expect(nodes).not_to be_empty
      expect(nodes.first.ID).to be_present
    end

    it "finds a node by ID" do
      node_id = described_class.all.first.ID
      node = described_class.find(node_id)
      expect(node).to be_present
      expect(node.ID).to eq(node_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Service
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Service do
    let(:name) { random_name("test_svc") }
    let(:params) do
      {
        Name: name,
        TaskTemplate: {
          ContainerSpec: {
            Image: "alpine:latest",
            Args: ["sleep", "3600"]
          }
        },
        Mode: {
          Replicated: {
            Replicas: 1
          }
        }
      }
    end

    describe "lifecycle" do
      subject(:service) { described_class.create(params) }

      after { service.destroy rescue nil }

      it "creates a service with an ID" do
        expect(service.ID).to be_present
      end

      it "finds the service by ID" do
        found = described_class.find(service.ID)
        expect(found).to be_present
        expect(found.ID).to eq(service.ID)
      end

      it "lists the service in .all" do
        service_id = service.ID
        expect(described_class.all.map(&:ID)).to include(service_id)
      end

      it "updates the service" do
        service # ensure creation
        new_params = {
          TaskTemplate: {
            ContainerSpec: {
              Image: "alpine:latest",
              Args: ["sleep", "7200"]
            }
          }
        }
        expect(service.update(new_params)).to be true
      end

      it "destroys the service" do
        service # ensure creation
        expect(service.destroy).to be true
      end

      it "returns logs" do
        service # ensure creation
        # Wait a bit for container to start
        sleep 2
        logs = service.logs
        # Service logs might be empty if it just started, but it shouldn't raise error
        expect(logs).to be_a(String)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Task do
    let(:service_name) { random_name("task_svc") }
    let(:service_params) do
      {
        Name: service_name,
        TaskTemplate: {
          ContainerSpec: {
            Image: "alpine:latest",
            Args: ["echo", "hello world"]
          }
        }
      }
    end

    it "lists tasks and gets logs" do
      service = DockerSwarm::Service.create(service_params)
      begin
        # Wait a bit for tasks to be created
        found_tasks = nil
        10.times do
          found_tasks = described_class.where(service: service_name)
          break if found_tasks.any?
          sleep 1
        end

        expect(found_tasks).not_to be_empty
        task = found_tasks.first
        expect(task.ID).to be_present
        
        # Wait for task to finish to have logs
        sleep 2
        logs = task.logs
        expect(logs).to be_a(String)
      ensure
        service.destroy rescue nil
      end
    end
  end
end
