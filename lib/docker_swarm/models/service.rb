# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Swarm Service
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Service
  class Service < Base
    include Concerns::Creatable
    include Concerns::Updatable
    include Concerns::Deletable
    include Concerns::Loggable

    # `status` es un query param **propio** de `GET /services` (Engine API ≥ v1.41), no un
    # filtro: con `?status=true` cada elemento del listado trae `ServiceStatus`
    # (`RunningTasks` · `DesiredTasks` · `CompletedTasks`).
    #
    # Es el **único** lugar donde el Engine publica el deseado de un service en modo
    # `global`. Un service replicado lo expone en `Spec.Mode.Replicated.Replicas`, pero
    # para uno global ese campo no existe —el deseado es "una task por nodo elegible"—,
    # así que sin `DesiredTasks` no hay número contra el cual comparar las tasks que
    # corren: un global degradado *parcialmente* (2 de 3 nodos) es indistinguible de uno
    # sano, y solo se detecta el caso extremo de cero tasks.
    #
    # Va acá y no en la whitelist de {DockerSwarm::Base} porque en `/containers/json`
    # `status` **sí** es un filtro válido (`running`, `exited`, …): globalizarlo lo sacaría
    # del `?filters=` y rompería `Container.where(status: "running")`.
    #
    # En un Engine por debajo de v1.41 el parámetro se ignora sin error y `ServiceStatus`
    # llega ausente → el consumidor tiene que tolerar `nil`.
    #
    # @return [Array<Symbol>] Symbols (no Strings como +create_query_params+): acá se
    #   matchea contra las claves de +filters+.
    def self.index_query_params
      (super + %i[status]).freeze
    end

    # Restarts the service by incrementing ForceUpdate, which causes
    # Docker to recreate all tasks.
    #
    # @return [Boolean] true if the restart was triggered successfully
    def restart
      current = self.Spec&.dig("TaskTemplate", "ForceUpdate").to_i
      update(Spec: { TaskTemplate: { ForceUpdate: current + 1 } })
    end
  end
end
