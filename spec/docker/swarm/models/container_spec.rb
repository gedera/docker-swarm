# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Container do
  let(:valid_attributes) { { "ID" => "container-123", "Names" => [ "/my-container" ] } }
  let(:container) { described_class.new(valid_attributes) }

  describe ".create" do
    let(:created) { { "Id" => "container-123", "Warnings" => [] } }

    it "manda el nombre por query string y lo saca del body" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(
          action: described_class.routes[:create],
          query_params: { name: "acs-seed-helper" }
        )
      ) do |args|
        expect(args[:payload]).not_to have_key("name")
        expect(args[:payload]).to include("Image" => "mongo:4.4")
        created
      end
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show])
      ).and_return(created)

      container = described_class.create(name: "acs-seed-helper", Image: "mongo:4.4")

      expect(container.ID).to eq("container-123")
    end

    it "no manda query params si no hay nombre" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:create], query_params: {})
      ).and_return(created)
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:show])
      ).and_return(created)

      described_class.create(Image: "mongo:4.4")
    end
  end

  describe ".create_query_params" do
    it "declara name" do
      expect(described_class.create_query_params).to eq(%w[name])
    end

    it "no lo declara en los modelos que no lo necesitan" do
      expect(DockerSwarm::Volume.create_query_params).to be_empty
    end
  end

  describe ".index_query_params (regresión #22)" do
    it "NO declara status: en containers es un filtro válido de Docker, no un query param" do
      expect(described_class.index_query_params).not_to include(:status)
    end

    it "sigue mandando status dentro del JSON de filters" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "status" => [ "running" ] }.to_json })
      ).and_return([])

      described_class.where(status: "running")
    end
  end

  describe ".index_query_params (#35)" do
    it "declara los tres query params propios de ContainerList" do
      expect(described_class.index_query_params).to eq(%i[all limit size])
    end

    it "manda since/before como FILTROS, no en la URL" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { filters: { "since" => [ "abc123" ] }.to_json })
      ).and_return([])

      described_class.where(since: "abc123")
    end

    it "manda size en la URL, no como filtro" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { size: true })
      ).and_return([])

      described_class.where(size: true)
    end

    it "no arrastra force, que no existe en el listado" do
      expect(described_class.index_query_params).not_to include(:force)
    end
  end

  describe "#start" do
    it "calls the start endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:start], arguments: { id: "container-123" })
      ).and_return(true)

      expect(container.start).to be true
    end
  end

  describe "#stop" do
    it "calls the stop endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:stop], arguments: { id: "container-123" })
      ).and_return(true)

      expect(container.stop).to be true
    end
  end

  describe "#logs" do
    it "calls the logs endpoint" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:logs], arguments: { id: "container-123" })
      ).and_return("container logs")

      expect(container.logs).to eq("container logs")
    end
  end

  # --- #39 · update / restart / stats -----------------------------------------
  #
  # Las tres faltaban y `Base#method_missing` hacía que la ausencia NO se notara:
  # devolvía `nil` sin levantar, y `respond_to?` decía `true` (ver #42). Aguas abajo
  # eso salía como `200 OK` con cuerpo nulo.

  describe "#restart" do
    it "pega al endpoint de restart y NO simula con ForceUpdate como Service" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:restart], arguments: { id: "container-123" })
      ).and_return(nil)

      expect(container.restart).to be true
    end

    it "manda t sólo si le pasan timeout" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { t: 5 })
      ).and_return(nil)

      container.restart(timeout: 5)
    end

    it "no manda t cuando es nil: el default del Engine no es lo mismo que t=0" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: {})
      ).and_return(nil)

      container.restart
    end
  end

  describe "#stats" do
    # 🚦 Si este spec se cae, el método deja de volver. Medido contra un Engine 29.7.2:
    # sin `stream=false` el endpoint emite un objeto por segundo y la conexión NO cierra
    # (`exit 28` de curl). En una llamada RPC eso cuelga, y el modo de falla no es un
    # error sino una espera.
    it "fuerza stream: false — sin eso el endpoint streamea y la llamada nunca vuelve" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(action: described_class.routes[:stats], query_params: { stream: false })
      ).and_return({ "memory_stats" => {} })

      container.stats
    end

    it "MERGEA los params en vez de reemplazarlos, así un caller no se queda colgado sin querer" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { stream: false, "one-shot" => true })
      ).and_return({})

      container.stats("one-shot" => true)
    end

    it "deja pisar stream a propósito" do
      expect(DockerSwarm::Api).to receive(:request).with(
        hash_including(query_params: { stream: true })
      ).and_return({})

      container.stats(stream: true)
    end

    it "devuelve el payload y no un booleano" do
      allow(DockerSwarm::Api).to receive(:request).and_return({ "memory_stats" => { "usage" => 42 } })

      expect(container.stats.dig("memory_stats", "usage")).to eq(42)
    end
  end

  describe "#update" do
    let(:ok) { { "Warnings" => nil } }

    before { allow(container).to receive(:reload) }

    it "pega al endpoint de update SIN version: ese query param es de services, no de containers" do
      expect(DockerSwarm::Api).to receive(:request) do |args|
        expect(args[:action]).to eq(described_class.routes[:update])
        expect(args[:query_params]).to be_nil
        expect(args[:payload]).to eq("Memory" => 134_217_728)
        ok
      end

      container.update("Memory" => 134_217_728)
    end

    it "devuelve el cuerpo del Engine y no true: ahí vienen los Warnings" do
      allow(DockerSwarm::Api).to receive(:request).and_return("Warnings" => [ "no swap limit" ])

      expect(container.update("Memory" => 1)).to eq("Warnings" => [ "no swap limit" ])
    end

    it "recarga el estado local, porque el payload es plano y el objeto lo tiene anidado" do
      allow(DockerSwarm::Api).to receive(:request).and_return(ok)
      expect(container).to receive(:reload)

      container.update("Memory" => 1)
    end

    # Sin esto, `c.Memory = X; c.save` postea {} y pierde el cambio: el Engine responde
    # 200 OK y no aplica nada (medido: body {} -> {"Warnings":null}, Memory sin cambiar).
    it "levanta con payload vacío en vez de dejar que el Engine responda 200 sin hacer nada" do
      expect(DockerSwarm::Api).not_to receive(:request)

      expect { container.update }.to raise_error(ArgumentError, /at least one attribute/)
    end

    it "el save sobre un container persistido levanta: no se soporta el save genérico" do
      expect(DockerSwarm::Api).not_to receive(:request)

      expect { container.save }.to raise_error(ArgumentError, /generic save/)
    end

    # `Creatable#save` llama `update(registry_auth:)`. Con una firma sin **opts ese kwarg
    # se vuelve Hash posicional en Ruby 3 y termina POSTEADO como atributo.
    it "descarta registry_auth: es cosa de Service y no debe viajar en el payload" do
      expect(DockerSwarm::Api).to receive(:request) do |args|
        expect(args[:payload]).to eq("Memory" => 1)
        ok
      end

      container.update({ "Memory" => 1 }, registry_auth: "SECRETO")
    end

    # Y si la credencial llega en el Hash POSICIONAL, el except tiene que alcanzarla igual:
    # de ahí pasa al payload y al log (`body=…`). Misma fuga que arregló #24 por el otro lado.
    it "descarta registry_auth aunque venga como clave String en el hash posicional" do
      expect(DockerSwarm::Api).not_to receive(:request)

      expect { container.update("registry_auth" => "SECRETO") }.to raise_error(ArgumentError)
    end
  end
end
