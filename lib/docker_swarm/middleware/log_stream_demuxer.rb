# frozen_string_literal: true

module DockerSwarm
  module Middleware
    # Demultiplexa el stream de logs del Engine para que +Concerns::Loggable#logs+
    # devuelva texto limpio en +Container+, +Service+ y +Task+.
    #
    # Sin TTY el Engine enmarca cada fragmento con 8 bytes de cabecera: 1 de tipo de
    # stream, 3 de relleno en cero y 4 de tamaño en big-endian. Ese framing tiene que
    # morir en un middleware y no en +Loggable+: +Connection#request+ devuelve
    # +response.body+ y descarta los headers, así que aguas abajo ya no queda
    # +Content-Type+ con el que decidir. Ver ADR-025 cláusula 3.
    #
    # @see https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerAttach
    class LogStreamDemuxer < Excon::Middleware::Base
      # Content-Type que **afirma** el framing. Existe desde la API v1.42.
      MULTIPLEXED_CONTENT_TYPE = "application/vnd.docker.multiplexed-stream"
      # Content-Type ambiguo: con TTY no hay framing, pero antes de v1.42 era el único
      # que existía y también viajaba en streams multiplexados.
      RAW_CONTENT_TYPE = "application/vnd.docker.raw-stream"

      # Tamaño de la cabecera de frame, en bytes.
      HEADER_SIZE = 8
      # Valores válidos del byte 0: stdin, stdout, stderr.
      STREAM_TYPES = [ 0, 1, 2 ].freeze

      def response_call(env)
        demux!(env) if env[:response]

        @stack.response_call(env)
      end

      private

      def demux!(env)
        body = env[:response][:body]
        return unless body.is_a?(String)
        return if body.empty?

        content_type = (env[:response][:headers] || {})["Content-Type"]
        return if content_type.nil?

        # Sobre +raw-stream+ no alcanza el Content-Type para descartar el framing: la
        # gema no fija +?version=+ (habla la versión máxima del Engine) y un nodo del
        # parque puede topar en v1.41, donde un stream multiplexado llega igual con
        # este Content-Type. Ahí decide la forma del frame, no el header.
        return unless content_type.include?(MULTIPLEXED_CONTENT_TYPE) ||
                      content_type.include?(RAW_CONTENT_TYPE)

        demuxed = demux(body)
        env[:response][:body] = demuxed unless demuxed.nil?
      end

      # Recorre el body entero como cadena de frames y concatena las cargas en orden.
      #
      # Es todo-o-nada a propósito: alcanza **una** inconsistencia —tipo de stream fuera
      # de rango, relleno distinto de cero, un tamaño que se pasa del buffer, una cola
      # suelta— para devolver +nil+ y dejar el body intacto. Un log de TTY tendría que
      # ser una cadena perfecta de frames válidos de punta a punta para confundirse.
      #
      # @param body [String] el body crudo tal como vino del Engine
      # @return [String, nil] el texto sin cabeceras, o +nil+ si el body no está enmarcado
      def demux(body)
        bytes = body.b
        size = bytes.bytesize
        offset = 0
        out = +""

        while offset < size
          return nil if size - offset < HEADER_SIZE

          stream_type, pad_a, pad_b, pad_c, length =
            bytes.byteslice(offset, HEADER_SIZE).unpack("C4N")

          return nil unless STREAM_TYPES.include?(stream_type)
          return nil unless pad_a.zero? && pad_b.zero? && pad_c.zero?

          offset += HEADER_SIZE
          return nil if size - offset < length

          out << bytes.byteslice(offset, length)
          offset += length
        end

        out.force_encoding(Encoding::UTF_8)
      end
    end
  end
end
