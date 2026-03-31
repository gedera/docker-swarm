# frozen_string_literal: true

module DockerSwarm
  class Api
    ENDPOINTS = {
      swarm: { show: { method: :get, path: "swarm" } },
      system: {
        info: { method: :get, path: "info" },
        version: { method: :get, path: "version" },
        up: { method: :get, path: "_ping" },
        df: { method: :get, path: "system/df" }
      },
      nodes: {
        index: { method: :get, path: "nodes" },
        show: { method: :get, path: "nodes/%<id>s" },
        update: { method: :post, path: "nodes/%<id>s/update" },
        destroy: { method: :delete, path: "nodes/%<id>s" }
      },
      tasks: {
        index: { method: :get, path: "tasks" },
        show: { method: :get, path: "tasks/%<id>s" },
        logs: { method: :get, path: "tasks/%<id>s/logs" }
      },
      services: {
        index: { method: :get, path: "services" },
        show: { method: :get, path: "services/%<id>s" },
        create: { method: :post, path: "services/create" },
        update: { method: :post, path: "services/%<id>s/update" },
        destroy: { method: :delete, path: "services/%<id>s" },
        logs: { method: :get, path: "services/%<id>s/logs" }
      },
      configs: {
        index: { method: :get, path: "configs" },
        show: { method: :get, path: "configs/%<id>s" },
        create: { method: :post, path: "configs/create" },
        destroy: { method: :delete, path: "configs/%<id>s" }
      },
      secrets: {
        index: { method: :get, path: "secrets" },
        show: { method: :get, path: "secrets/%<id>s" },
        create: { method: :post, path: "secrets/create" },
        destroy: { method: :delete, path: "secrets/%<id>s" }
      },
      networks: {
        index: { method: :get, path: "networks" },
        show: { method: :get, path: "networks/%<id>s" },
        create: { method: :post, path: "networks/create" },
        update: { method: :post, path: "networks/%<id>s/update" },
        destroy: { method: :delete, path: "networks/%<id>s" }
      },
      volumes: {
        index: { method: :get, path: "volumes" },
        show: { method: :get, path: "volumes/%<id>s" },
        create: { method: :post, path: "volumes/create" },
        destroy: { method: :delete, path: "volumes/%<id>s" }
      },
      containers: {
        index: { method: :get, path: "containers/json" },
        show: { method: :get, path: "containers/%<id>s/json" },
        create: { method: :post, path: "containers/create" },
        start: { method: :post, path: "containers/%<id>s/start" },
        stop: { method: :post, path: "containers/%<id>s/stop" },
        destroy: { method: :delete, path: "containers/%<id>s" },
        logs: { method: :get, path: "containers/%<id>s/logs" }
      },
      images: {
        index: { method: :get, path: "images/json" },
        show: { method: :get, path: "images/%<id>s/json" },
        create: { method: :post, path: "images/create?fromImage=%<id>s" },
        destroy: { method: :delete, path: "images/%<id>s" }
      }
    }.freeze

    def self.request(action:, arguments: {}, query_params: {}, payload: nil)
      path = format(action[:path], arguments)
      DockerSwarm.request(
        method: action[:method],
        path: path,
        query: query_params,
        body: payload
      )
    end
  end
end
