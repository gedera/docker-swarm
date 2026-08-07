# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Container
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Container
  class Container < Base
    include Concerns::Creatable
    include Concerns::Deletable
    include Concerns::Loggable

    # +POST /containers/create+ toma el nombre por query string. En el body Docker lo
    # **descarta en silencio** y responde +201+: el container nace con nombre aleatorio
    # y la adopción por nombre determinista en un reintento no encuentra nada, así que
    # el reintento duplica. Ver ADR-025 cláusula 1.
    # @return [Array<String>]
    def self.create_query_params
      %w[name].freeze
    end

    # `GET /containers/json` declara exactamente tres query params propios además de
    # `filters`: `all`, `limit` y `size` (spec v1.41, `ContainerList`).
    #
    # No hereda el default de {DockerSwarm::Base} porque **`since` y `before` son
    # filtros** de este recurso, no query params: ruteados a la URL el Engine los ignora
    # y devuelve **la lista sin filtrar, sin error** — resultado incorrecto silencioso,
    # peor que el rechazo ruidoso de #22. Y `size` faltaba: es query param propio (pide
    # el tamaño de los archivos del container), así que viajaba dentro de `filters` como
    # filtro inválido. Ver #35.
    #
    # @return [Array<Symbol>] Symbols (matchean contra las claves de `filters`)
    def self.index_query_params
      %i[all limit size].freeze
    end

    # Starts the container
    # @return [Boolean] true if successful
    def start
      Api.request(action: self.class.routes[:start], arguments: { id: self.ID })
      true
    end

    # Stops the container
    # @return [Boolean] true if successful
    def stop
      Api.request(action: self.class.routes[:stop], arguments: { id: self.ID })
      true
    end
  end
end
