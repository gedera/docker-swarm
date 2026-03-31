# frozen_string_literal: true

module DockerSwarm
  class Task < Base
    def logs(query_params = { stdout: 1, stderr: 1 })
      Api.request(action: self.class.routes[:logs], arguments: { id: self.ID }, query_params: query_params)
    end
  end
end
