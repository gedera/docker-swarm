# frozen_string_literal: true

require "integration_helper"

RSpec.describe "DockerSwarm Containers Integration", type: :integration do
  # ---------------------------------------------------------------------------
  # Image
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Image do
    it "lists images" do
      images = described_class.all
      expect(images).not_to be_empty
      expect(images.first.ID).to be_present
    end

    it "finds an image by ID" do
      image_id = described_class.all.first.ID
      image = described_class.find(image_id)
      expect(image).to be_present
      expect(image.ID).to eq(image_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Container
  # ---------------------------------------------------------------------------
  describe DockerSwarm::Container do
    it "lists all containers" do
      containers = described_class.all
      # Might be empty if no containers are running
      expect(containers).to be_an(Array)
    end

    it "finds a container by ID if any exists" do
      containers = described_class.all
      if containers.any?
        container_id = containers.first.ID
        container = described_class.find(container_id)
        expect(container).to be_present
        expect(container.ID).to eq(container_id)
      else
        skip "No containers available to test find"
      end
    end

    # --- #39 · update / restart / stats contra el Engine real -----------------
    #
    # Los unitarios mockean `Api.request`, así que prueban que MANDAMOS los
    # parámetros correctos — no que el Engine haga lo que esperamos. Estos tres
    # son la otra mitad, y hay uno que un unitario **no puede** cubrir: que
    # `stats` VUELVA. Con el default (`stream=true`) la conexión queda abierta
    # emitiendo un objeto por segundo y la llamada no termina nunca.
    describe "update / restart / stats (#39)" do
      # Nombre único POR EJEMPLO, no por corrida: si uno se filtra, el siguiente
      # falla con `409 Conflict` y el error real queda tapado por el del nombre.
      let(:name) { "docker-swarm-spec-#{Process.pid}-#{SecureRandom.hex(4)}" }
      let(:container) { described_class.find(name) }

      before do
        described_class.create(
          name: name,
          Image: "busybox:1.37",
          Cmd: [ "sh", "-c", "while true; do sleep 1; done" ],
          HostConfig: { "Memory" => 67_108_864, "MemorySwap" => 67_108_864 }
        )
        container.start
      end

      # ⚠️ `stop` antes de `destroy`, y NO `destroy(force: true)`: `Deletable#destroy`
      # **no acepta argumentos** (issue #38), así que el `force:` levanta `ArgumentError`,
      # el rescue se lo come y el container queda vivo — el ejemplo siguiente choca con
      # `409 Conflict` y el error real se pierde detrás del conflicto de nombre.
      after do
        c = described_class.find(name)
        c.stop
        c.destroy
      rescue StandardError
        nil
      end

      it "stats vuelve en vez de colgarse, y trae métricas" do
        stats = Timeout.timeout(15) { container.stats }

        expect(stats.dig("memory_stats", "usage")).to be_present
      end

      it "restart reinicia de verdad: StartedAt se mueve" do
        antes = container.State["StartedAt"]

        expect(container.restart(timeout: 1)).to be true

        expect(described_class.find(name).State["StartedAt"]).not_to eq(antes)
      end

      it "update aplica el límite y deja el objeto local al día" do
        expect(container.HostConfig["Memory"]).to eq(67_108_864)

        container.update("Memory" => 134_217_728, "MemorySwap" => 134_217_728)

        # El objeto se recargó solo (no hace falta un find nuevo)…
        expect(container.HostConfig["Memory"]).to eq(134_217_728)
        # …y el Engine lo tiene de verdad, no sólo nuestro objeto.
        expect(described_class.find(name).HostConfig["Memory"]).to eq(134_217_728)
      end

      it "update con payload vacío levanta en vez de mandar un no-op al Engine" do
        expect { container.update }.to raise_error(ArgumentError, /at least one attribute/)

        expect(described_class.find(name).HostConfig["Memory"]).to eq(67_108_864)
      end
    end
  end
end
