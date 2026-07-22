# frozen_string_literal: true

module DockerSwarm
  # Represents a Docker Image
  # @see https://docs.docker.com/engine/api/v1.41/#tag/Image
  #
  # No incluye Creatable: el "create" del Docker API sobre imágenes es un PULL
  # (stream de progreso), no la construcción de un recurso CRUD. Se expone como
  # `.pull` con contrato propio.
  class Image < Base
    include Concerns::Deletable

    # Docker emite el digest del pull en un frame de status "Digest: sha256:..."
    # (verificado empíricamente contra Docker 29.5.3; el stream de pull NO trae campo `aux`).
    DIGEST_STATUS = /\bDigest:\s*(sha256:[0-9a-f]+)/

    class << self
      # Pull explícito de una imagen (POST /images/create).
      #
      # Operación SÍNCRONA: consume el stream NDJSON de progreso hasta EOF, eleva
      # error tipado ante un frame `error`/`errorDetail` (que Docker manda CON HTTP 200),
      # y solo tras terminación limpia devuelve un resultado explícito construido desde
      # el stream — sin un `find` posterior que reintroduciría el problema referencia-vs-ID.
      #
      # @param image_reference [String] referencia completa (registry/repo:tag o @sha256:...)
      # @param registry_auth [String, nil] credencial opaca base64url → header X-Registry-Auth
      # @return [Hash] { status: :pulled, image_ref: String, digest: String (si Docker lo emite) }
      # @raise [DockerSwarm::Error] si el stream reporta error/errorDetail
      def pull(image_reference, registry_auth: nil)
        headers, = RegistryAuth.resolve(registry_auth: registry_auth)

        body = Api.request(
          action: routes[:pull],
          query_params: { fromImage: image_reference },
          headers: headers
        )

        frames = parse_progress_stream(body)
        raise_on_stream_error!(frames)
        pull_result(image_reference, frames)
      end

      private

      # El middleware entrega el stream como String (multi-frame NDJSON: el JSON.parse
      # global falló y devolvió el cuerpo crudo) o como Hash (un único objeto JSON, p. ej.
      # algunos errores). Normalizamos a una lista de frames-Hash en ambos casos.
      def parse_progress_stream(body)
        case body
        when Hash
          [ body ]
        when String
          body.each_line.filter_map { |line| parse_frame(line) }
        else
          []
        end
      end

      def parse_frame(line)
        line = line.strip
        return if line.empty?

        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end

      def raise_on_stream_error!(frames)
        error_frame = frames.find { |frame| frame["error"] || frame["errorDetail"] }
        return unless error_frame

        detail = error_frame.dig("errorDetail", "message") || error_frame["error"]
        raise DockerSwarm::Error, "image pull failed: #{detail}"
      end

      def pull_result(image_reference, frames)
        digest = extract_digest(frames)

        result = { status: :pulled, image_ref: image_reference }
        result[:digest] = digest if digest
        result
      end

      # Escaneamos desde el final para quedarnos con el frame "Digest:" más reciente.
      def extract_digest(frames)
        frames.reverse_each do |frame|
          match = DIGEST_STATUS.match(frame["status"].to_s)
          return match[1] if match
        end
        nil
      end
    end
  end
end
