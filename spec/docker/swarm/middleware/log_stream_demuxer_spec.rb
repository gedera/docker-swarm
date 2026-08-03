# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Middleware::LogStreamDemuxer do
  let(:stack) { double("stack") }
  let(:middleware) { described_class.new(stack) }

  # Arma un frame multiplexado: 1 byte de tipo, 3 de relleno, 4 de tamaño BE.
  def frame(payload, stream_type: 1)
    [ stream_type, 0, 0, 0, payload.bytesize ].pack("C4N") + payload
  end

  def env_for(body, content_type:)
    { response: { body: body, headers: { "Content-Type" => content_type } } }
  end

  def body_after(env)
    result = nil
    expect(stack).to receive(:response_call) { |e| result = e[:response][:body] }
    middleware.response_call(env)
    result
  end

  describe "#response_call" do
    context "con Content-Type multiplexed-stream" do
      let(:content_type) { described_class::MULTIPLEXED_CONTENT_TYPE }

      it "concatena las cargas de los frames en orden y saca las cabeceras" do
        body = frame("primera\n") + frame("segunda\n")

        expect(body_after(env_for(body, content_type: content_type))).to eq("primera\nsegunda\n")
      end

      it "intercala stdout y stderr respetando el orden del stream" do
        body = frame("out-1\n", stream_type: 1) +
               frame("err-1\n", stream_type: 2) +
               frame("out-2\n", stream_type: 1)

        expect(body_after(env_for(body, content_type: content_type))).to eq("out-1\nerr-1\nout-2\n")
      end

      it "preserva el contenido entre delimitadores del Cmd" do
        body = frame("mongod ruido de arranque\n") +
               frame("---WISPRO-BEGIN---\nDevices\t12330\n---WISPRO-END---\n")

        expect(body_after(env_for(body, content_type: content_type)))
          .to include("---WISPRO-BEGIN---\nDevices\t12330\n---WISPRO-END---\n")
      end

      it "devuelve el texto en UTF-8" do
        result = body_after(env_for(frame("ñandú\n"), content_type: content_type))

        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result).to eq("ñandú\n")
      end

      it "tolera un frame de tamaño cero" do
        body = frame("") + frame("algo\n")

        expect(body_after(env_for(body, content_type: content_type))).to eq("algo\n")
      end
    end

    context "con Content-Type raw-stream" do
      let(:content_type) { described_class::RAW_CONTENT_TYPE }

      # El caso que el Content-Type solo NO cubre: Engine que topa en API v1.41.
      it "demultiplexa igual si el body está enmarcado" do
        body = frame("desde un engine v1.41\n")

        expect(body_after(env_for(body, content_type: content_type)))
          .to eq("desde un engine v1.41\n")
      end

      it "deja intacto un log de TTY sin framing" do
        body = "log plano de tty\nsegunda linea\n"

        expect(body_after(env_for(body, content_type: content_type))).to eq(body)
      end
    end

    context "cuando el framing no es consistente de punta a punta" do
      let(:content_type) { described_class::MULTIPLEXED_CONTENT_TYPE }

      it "deja el body intacto si el tipo de stream está fuera de rango" do
        body = [ 9, 0, 0, 0, 4 ].pack("C4N") + "dato"

        expect(body_after(env_for(body, content_type: content_type))).to eq(body)
      end

      it "deja el body intacto si el relleno no es cero" do
        body = [ 1, 0, 7, 0, 4 ].pack("C4N") + "dato"

        expect(body_after(env_for(body, content_type: content_type))).to eq(body)
      end

      it "deja el body intacto si el tamaño se pasa del buffer" do
        body = [ 1, 0, 0, 0, 999 ].pack("C4N") + "corto"

        expect(body_after(env_for(body, content_type: content_type))).to eq(body)
      end

      it "deja el body intacto si queda una cola más corta que una cabecera" do
        body = frame("completo\n") + "cola"

        expect(body_after(env_for(body, content_type: content_type))).to eq(body)
      end
    end

    context "cuando no corresponde tocar el body" do
      it "no toca una respuesta JSON" do
        body = '{"ID":"123"}'

        expect(body_after(env_for(body, content_type: "application/json"))).to eq(body)
      end

      it "no toca el body si no hay Content-Type" do
        body = frame("igual queda enmarcado\n")
        env = { response: { body: body, headers: {} } }

        expect(body_after(env)).to eq(body)
      end

      it "no falla si el body está vacío" do
        expect(body_after(env_for("", content_type: described_class::MULTIPLEXED_CONTENT_TYPE))).to eq("")
      end

      it "no falla si el body ya no es un String" do
        env = env_for({ "ID" => "123" }, content_type: "application/json")

        expect(body_after(env)).to eq({ "ID" => "123" })
      end

      it "no falla si la respuesta no existe" do
        env = {}
        expect(stack).to receive(:response_call).with(env)

        middleware.response_call(env)
      end
    end
  end
end
