# frozen_string_literal: true

module DockerSwarm
  class Container < Base
    include Concerns::Deletable

    def start
      Api.request(action: self.class.routes[:start], arguments: { id: self.ID })
    end

    def stop
      Api.request(action: self.class.routes[:stop], arguments: { id: self.ID })
    end

    def logs(query_params = { stdout: 1, stderr: 1 })
      Api.request(action: self.class.routes[:logs], arguments: { id: self.ID }, query_params: query_params)
    end
  end
end
