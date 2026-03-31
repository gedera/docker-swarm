# frozen_string_literal: true

module DockerSwarm
  class Connection
    attr_reader :socket_path, :logger

    def initialize(socket_path, logger)
      @socket_path = socket_path
      @logger = logger
    end

    def request(options = {})
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      log_event("request_started",
                level: :debug,
                data: options.merge(path: options[:path]))

      # Combinar opciones por defecto de la gema con las de la petición
      request_options = {
        idempotent: true,
        retry_errors: [ Excon::Error::Socket, Excon::Error::Timeout ],
        read_timeout: DockerSwarm.configuration.read_timeout.to_f,
        write_timeout: DockerSwarm.configuration.write_timeout.to_f,
        connect_timeout: DockerSwarm.configuration.connect_timeout.to_f,
        retries: DockerSwarm.configuration.max_retries.to_i
      }.merge(options)

      response = client.request(request_options)

      log_event("request_success",
                data: options.merge(
                  status: response.status,
                  duration_ms: calculate_duration(start_time)
                ))

      response.body
    rescue => e
      # Excon suele envolver excepciones de middleware en Excon::Error::Socket.
      # Intentamos recuperar la causa original si es una de nuestras excepciones.
      actual_error = (e.respond_to?(:cause) && e.cause&.class&.name&.include?("DockerSwarm::Error")) ? e.cause : e

      log_event("request_failure",
                level: :error,
                data: options.merge(
                  error: actual_error.class.name,
                  message: actual_error.message,
                  duration_ms: calculate_duration(start_time)
                ))

      if actual_error.class.name.include?("DockerSwarm::Error")
        raise actual_error
      elsif actual_error.is_a?(Excon::Error::Socket)
        raise ::DockerSwarm::Error::Communication, "Docker socket error: #{actual_error.message}"
      else
        raise actual_error
      end
    end

    private

    def log_event(event, level: :info, data: {})
      return unless logger
      # Respetar el nivel de log antes de procesar nada
      return if level == :debug && logger.level > Logger::DEBUG

      log_block = proc do
        LogHelper.format_kv({
          component: "docker_swarm.connection",
          event: event,
          source: "http"
        }.merge(data))
      end

      if level == :debug
        logger.debug(&log_block)
      else
        logger.send(level, log_block.call)
      end
    end

    def calculate_duration(start_time)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    end

    def common_middlewares
      # Usamos los middlewares por defecto de Excon para garantizar que todas las llaves internas
      # (como :retries_remaining o :instrumentor_name) se inicialicen correctamente.
      Excon.defaults[:middlewares] + [
        Excon::Middleware::RedirectFollower,
        Middleware::RequestEncoder,
        Middleware::ResponseJSONParser,
        Middleware::ErrorHandler
      ]
    end

    def client
      debug_enabled = logger&.level == Logger::DEBUG

      options = {
        middlewares: common_middlewares,
        logger: logger,
        debug_request: debug_enabled,
        debug_response: debug_enabled,
        # Si debug_enabled es true, Excon usará su lógica interna de debug con el logger proporcionado
        retry_limit: 0
      }

      @client ||= if socket_path.start_with?("unix://")
                    Excon.new("unix:///", options.merge(socket: socket_path.sub(/^unix:\/\//, "")))
      else
                    Excon.new(socket_path, options)
      end
    end
  end
end
