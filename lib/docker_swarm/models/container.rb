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

    # Actualiza los límites de recursos del container (+POST /containers/{id}/update+).
    #
    # ⚠️ **NO usa {Concerns::Updatable}, y no es un olvido.** Ese concern está escrito para
    # services de Swarm: manda +?version=<Version.Index>+ para el control de concurrencia
    # optimista y serializa con +payload_for_docker+. El update de un **container** no tiene
    # +version+ — es otro endpoint con otra semántica (cpu, memoria, reinicio) — así que
    # incluirlo mandaría un query param que el Engine **ignora en silencio**.
    #
    # 🚦 **La firma absorbe kwargs a propósito.** {Concerns::Creatable#save} llama
    # +update(registry_auth:)+ cuando el objeto ya está persistido; con una firma
    # +update(new_attributes = {})+ ese kwarg se convierte en Hash posicional (Ruby 3) y
    # terminaría **posteado como atributo**: +{"registry_auth": null}+ hacia el Engine, sin
    # error. Los dos de registry se descartan acá porque son cosa de +Service+ (header
    # +X-Registry-Auth+ / query +registryAuthFrom+); un container no autentica en su update.
    #
    # Devuelve el cuerpo de la respuesta —Docker responde +{"Warnings": [...]}+— y **no un
    # booleano**: el Engine avisa por ahí cuando un límite no se pudo aplicar. Colapsarlo a
    # +true+ se comería justamente la señal.
    #
    # @param new_attributes [Hash] límites de recursos en el shape de Docker (+Memory+,
    #   +NanoCpus+, +RestartPolicy+, …)
    # @param opts [Hash] atributos sueltos; +registry_auth+ y +registry_auth_from+ se descartan
    # @return [Hash] cuerpo de la respuesta del Engine (+Warnings+)
    def update(new_attributes = {}, **opts)
      opts = opts.except(:registry_auth, :registry_auth_from)

      Api.request(
        action: self.class.routes[:update],
        arguments: { id: self.ID },
        payload: new_attributes.merge(opts)
      )
    end

    # Reinicia el container (+POST /containers/{id}/restart+).
    #
    # ⚠️ **No se parece a {Service#restart}, y está bien.** El hermano simula el restart
    # incrementando +ForceUpdate+ **porque los services de Swarm no tienen endpoint de
    # restart**. Los containers sí lo tienen, así que copiar ese workaround sería arrastrar
    # una vuelta que acá no hace falta.
    #
    # @param timeout [Integer, nil] segundos a esperar antes de matar el proceso (+t+ de
    #   Docker). +nil+ deja el default del Engine, que **no** es lo mismo que mandar +0+
    #   (eso mataría sin gracia).
    # @return [Boolean] true si el Engine aceptó el reinicio
    def restart(timeout: nil)
      Api.request(
        action: self.class.routes[:restart],
        arguments: { id: self.ID },
        query_params: timeout.nil? ? {} : { t: timeout }
      )
      true
    end

    # Métricas de uso del container (+GET /containers/{id}/stats+).
    #
    # 🚦 **`stream: false` NO es un default cómodo: es lo que hace que el método vuelva.**
    # El endpoint streamea por default —+stream=true+— y la conexión queda abierta emitiendo
    # un objeto por segundo. Medido contra un Engine **29.7.2**: sin el parámetro, 6 objetos
    # en 6 s y la conexión **no cierra** (+exit 28+ de curl); con +stream=false+, un objeto y
    # cierra en 1 s. En una llamada RPC el default **cuelga** — y el modo de falla no es un
    # error, es una espera. Mismo patrón que ADR-027: el default de Docker no es el que sirve.
    #
    # Por eso el parámetro se **mergea** en vez de reemplazarse, que es como lo hace
    # {Concerns::Loggable#logs}: ahí un caller que pasa su propio hash sólo cambia qué streams
    # lee; acá lo dejaría colgado. Se puede pisar a propósito (+stats(stream: true)+), pero no
    # por accidente.
    #
    # @param query_params [Hash] parámetros extra (+one-shot+, …). +stream+ va en +false+
    #   salvo que se lo pise explícitamente.
    # @return [Hash] snapshot de métricas parseado
    def stats(query_params = {})
      Api.request(
        action: self.class.routes[:stats],
        arguments: { id: self.ID },
        query_params: { stream: false }.merge(query_params)
      )
    end
  end
end
