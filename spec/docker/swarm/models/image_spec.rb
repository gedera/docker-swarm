# frozen_string_literal: true

require "spec_helper"

# Contrato OBJETIVO de DockerSwarm::Image.pull (pull explícito de una imagen).
#
# Red-for-future (TDD): estos ejemplos describen el comportamiento deseado y están
# SKIPPED hasta que `.pull` se implemente. Documentan por qué el flujo actual está roto:
#   - `Image` solo incluye Creatable/Deletable → `Image.pull` no existe (NoMethodError);
#   - la ruta `images/create?fromImage=%<id>s` interpola por path y `Creatable#save` no pasa
#     `arguments:`, así que el `%<id>s` queda sin resolver;
#   - el shared CRUD spec mockea `Api.request`, ocultando ambos defectos.
#
# Se mockea `DockerSwarm.request` (la capa DEBAJO de `Api.request`) a propósito: así la
# construcción real de path/query se ejercita (a diferencia del shared spec que mockea
# `Api.request` y esconde el bug).
RSpec.describe DockerSwarm::Image do
  let(:image_ref) { "registry.example.com/team/app:latest" }
  let(:encoded_auth) { "eyJ1c2VybmFtZSI6Ii4uLiJ9" } # base64url(JSON AuthConfig), valor opaco

  describe ".index_query_params (#35)" do
    it "declara los dos query params propios de ImageList" do
      expect(described_class.index_query_params).to eq(%i[all digests])
    end

    it "manda since/before como FILTROS, no en la URL" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "since" => [ "alpine:3.18" ] }.to_json })
      ).and_return([])

      described_class.where(since: "alpine:3.18")
    end

    it "manda digests en la URL, no como filtro" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { digests: true })
      ).and_return([])

      described_class.where(digests: true)
    end
  end

  describe ".pull" do
    it "existe como operación de clase" do
      expect(described_class).to respond_to(:pull)
    end

    it "hace POST images/create con fromImage en QUERY (no interpolado en el path)" do
      expect(DockerSwarm).to receive(:request).with(
        hash_including(
          method: :post,
          path: "images/create",
          query: hash_including(fromImage: image_ref)
        )
      ).and_return("{\"status\":\"Downloaded newer image for #{image_ref}\"}")

      described_class.pull(image_ref)
    end

    it "imagen pública: NO envía header X-Registry-Auth" do
      expect(DockerSwarm).to receive(:request) do |opts|
        expect(opts[:headers] || {}).not_to have_key("X-Registry-Auth")
        "{\"status\":\"Status: Downloaded newer image for #{image_ref}\"}"
      end

      described_class.pull(image_ref)
    end

    it "imagen privada: envía X-Registry-Auth con el valor opaco, sin loguearlo" do
      expect(DockerSwarm).to receive(:request).with(
        hash_including(headers: hash_including("X-Registry-Auth" => encoded_auth))
      ).and_return("{\"status\":\"Downloaded\"}")

      described_class.pull(image_ref, registry_auth: encoded_auth)
    end

    it "referencia con registry/tag/digest: fromImage codificado de forma segura" do
      ref = "registry.example.com/team/app@sha256:abc123"
      expect(DockerSwarm).to receive(:request).with(
        hash_including(query: hash_including(fromImage: ref))
      ).and_return("{\"status\":\"Downloaded\"}")

      described_class.pull(ref)
    end

    context "errores embebidos en el stream (HTTP 200)" do
      it "eleva un error tipado ante un frame error/errorDetail (NO falso éxito)" do
        ndjson = [
          "{\"status\":\"Pulling from team/app\"}",
          "{\"errorDetail\":{\"message\":\"unauthorized\"},\"error\":\"unauthorized\"}"
        ].join("\n")
        allow(DockerSwarm).to receive(:request).and_return(ndjson)

        expect { described_class.pull(image_ref, registry_auth: encoded_auth) }
          .to raise_error(DockerSwarm::Error, /unauthorized/)
      end

      it "el mensaje de error NO contiene la credencial" do
        ndjson = "{\"error\":\"denied\"}"
        allow(DockerSwarm).to receive(:request).and_return(ndjson)

        expect { described_class.pull(image_ref, registry_auth: encoded_auth) }
          .to raise_error(DockerSwarm::Error) { |e| expect(e.message).not_to include(encoded_auth) }
      end
    end

    context "retorno tras terminación limpia" do
      # Forma REAL del stream de un pull (capturada contra Docker 29.5.3): el digest
      # viaja en un frame de status "Digest: sha256:...", NO en un campo `aux`.
      let(:digest) { "sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1" }
      let(:clean_stream) do
        [
          "{\"status\":\"Pulling from team/app\",\"id\":\"latest\"}",
          "{\"status\":\"Digest: #{digest}\"}",
          "{\"status\":\"Status: Downloaded newer image for #{image_ref}\"}"
        ].join("\n")
      end

      it "devuelve un resultado explícito { status:, image_ref:, digest }, sin hacer find" do
        expect(described_class).not_to receive(:find)
        allow(DockerSwarm).to receive(:request).and_return(clean_stream)

        expect(described_class.pull(image_ref)).to eq(status: :pulled, image_ref: image_ref, digest: digest)
      end

      it "up-to-date (imagen ya presente) también resuelve status :pulled con su digest" do
        stream = [
          "{\"status\":\"Pulling from team/app\",\"id\":\"latest\"}",
          "{\"status\":\"Digest: #{digest}\"}",
          "{\"status\":\"Status: Image is up to date for #{image_ref}\"}"
        ].join("\n")
        allow(DockerSwarm).to receive(:request).and_return(stream)

        expect(described_class.pull(image_ref)).to eq(status: :pulled, image_ref: image_ref, digest: digest)
      end

      it "omite digest si el stream no emitió el frame Digest:" do
        allow(DockerSwarm).to receive(:request).and_return("{\"status\":\"Status: Downloaded\"}")

        expect(described_class.pull(image_ref)).to eq(status: :pulled, image_ref: image_ref)
      end
    end

    context "forma del body polimórfica (Hash|String)" do
      it "maneja body String (NDJSON multi-frame, JSON.parse falló → crudo)" do
        allow(DockerSwarm).to receive(:request).and_return(
          "{\"status\":\"Pulling\"}\n{\"status\":\"Downloaded newer image for #{image_ref}\"}"
        )
        expect { described_class.pull(image_ref) }.not_to raise_error
      end

      it "maneja body Hash (objeto JSON único parseado por el middleware)" do
        allow(DockerSwarm).to receive(:request).and_return(
          { "status" => "Downloaded newer image for #{image_ref}" }
        )
        expect { described_class.pull(image_ref) }.not_to raise_error
      end
    end
  end

  # Image conserva el resto del lifecycle (Deletable + listado); solo NO es Creatable.
  # Esta cobertura migró del shared CRUD spec al retirar Image de los recursos genéricos.
  describe "resto del lifecycle" do
    it "NO expone .create (el pull reemplaza al create genérico)" do
      expect(described_class).not_to respond_to(:create)
    end

    it "borra una imagen por ID (Deletable)" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:destroy], arguments: { id: "img-123" })
      ).and_return(true)

      expect(described_class.destroy("img-123")).to be true
    end

    it "lista las imágenes (.all)" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:index])
      ).and_return([ { "ID" => "img-123" } ])

      images = described_class.all
      expect(images.first).to be_a(described_class)
      expect(images.first.ID).to eq("img-123")
    end
  end
end
