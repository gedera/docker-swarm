# Pruebas y Mocking

Al integrar `docker-swarm` en tu aplicacion, necesitas evitar que los tests realicen llamadas reales al socket de Docker.

## Configuracion de Tests

En tu `spec_helper.rb` o `rails_helper.rb`, configura la gema con valores ficticios:

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:suite) do
    DockerSwarm.configure do |swarm_config|
      swarm_config.socket_path = "unix:///tmp/docker-fake.sock"
      swarm_config.logger = Logger.new("/dev/null")
    end
  end
end
```

## Estrategia Principal: Mockear Api.request

La forma mas efectiva es mockear `DockerSwarm::Api.request`, que es el punto de entrada de todas las operaciones del ORM.

### CRUD basico

```ruby
# app/services/deployer.rb
class Deployer
  def scale_service(id, replicas)
    service = DockerSwarm::Service.find(id)
    service.update(Mode: { Replicated: { Replicas: replicas } })
  end
end

# spec/services/deployer_spec.rb
RSpec.describe Deployer do
  let(:service_data) do
    {
      "ID" => "svc-123",
      "Version" => { "Index" => 1 },
      "Spec" => { "Name" => "web", "Mode" => { "Replicated" => { "Replicas" => 1 } } }
    }
  end

  it "escala el servicio correctamente" do
    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:show])
    ).and_return(service_data)

    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:update])
    ).and_return(true)

    expect(Deployer.new.scale_service("svc-123", 5)).to be true
  end
end
```

### Listar recursos

```ruby
it "lista servicios con filtros" do
  expect(DockerSwarm::Api).to receive(:request).with(
    hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:index])
  ).and_return([service_data])

  services = DockerSwarm::Service.all(label: ["env=prod"])
  expect(services.size).to eq(1)
  expect(services.first.ID).to eq("svc-123")
end
```

### Crear recursos

```ruby
it "crea un servicio" do
  expect(DockerSwarm::Api).to receive(:request).with(
    hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:create])
  ).and_return({ "ID" => "svc-new" })

  # El create hace reload despues de crear
  expect(DockerSwarm::Api).to receive(:request).with(
    hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:show])
  ).and_return(service_data.merge("ID" => "svc-new"))

  service = DockerSwarm::Service.create(Name: "web", TaskTemplate: { ContainerSpec: { Image: "nginx" } })
  expect(service.persisted?).to be true
end
```

## Mockear Errores

Simula errores de Docker para verificar el manejo en tu aplicacion.

### Error de recurso no encontrado

```ruby
it "maneja servicio inexistente" do
  expect(DockerSwarm::Api).to receive(:request).and_raise(
    DockerSwarm::NotFound.new("service not found")
  )

  # Base.find captura NotFound y retorna nil
  expect(DockerSwarm::Service.find("missing")).to be_nil
end
```

### Error de conflicto (nombre duplicado)

```ruby
it "maneja conflicto al crear" do
  expect(DockerSwarm::Api).to receive(:request).and_raise(
    DockerSwarm::Conflict.new("name conflicts with existing")
  )

  expect {
    DockerSwarm::Network.create(Name: "existing-net")
  }.to raise_error(DockerSwarm::Conflict)
end
```

### Error de conexion (Docker caido)

```ruby
it "maneja Docker inalcanzable" do
  expect(DockerSwarm::Api).to receive(:request).and_raise(
    DockerSwarm::Communication.new("Docker socket error: connection refused")
  )

  expect {
    DockerSwarm::System.up
  }.to raise_error(DockerSwarm::Communication)
end
```

### Errores HTTP genericos

```ruby
# Usa cualquier excepcion de la jerarquia
DockerSwarm::BadRequest          # 400
DockerSwarm::Unauthorized        # 401
DockerSwarm::Forbidden           # 403
DockerSwarm::Conflict            # 409
DockerSwarm::InternalServerError # 500
DockerSwarm::ServiceUnavailable  # 503
```

## Mockear a Nivel Bajo

Si necesitas control total, mockea `DockerSwarm.request` directamente (bypass del ORM):

```ruby
allow(DockerSwarm).to receive(:request).and_return({ "Status" => "OK" })
```

## Helper de Test (opcional)

Si mockeas Docker frecuentemente, un helper simplifica el setup:

```ruby
# spec/support/docker_swarm_helpers.rb
module DockerSwarmHelpers
  def stub_docker_find(model, id, data)
    resource = model.name.demodulize.downcase.pluralize.to_sym
    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[resource][:show])
    ).and_return(data.merge("ID" => id))
  end

  def stub_docker_list(model, items)
    resource = model.name.demodulize.downcase.pluralize.to_sym
    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[resource][:index])
    ).and_return(items)
  end
end

RSpec.configure do |config|
  config.include DockerSwarmHelpers
end
```

Uso:

```ruby
it "encuentra el servicio" do
  stub_docker_find(DockerSwarm::Service, "svc-1", { "Spec" => { "Name" => "web" } })
  service = DockerSwarm::Service.find("svc-1")
  expect(service.Spec[:Name]).to eq("web")
end
```

## Resumen

| Que testear | Como mockear |
| :--- | :--- |
| Modelos (ORM) | `expect(DockerSwarm::Api).to receive(:request)` |
| Llamadas API directas | `allow(DockerSwarm).to receive(:request)` |
| Errores de red | Raise `DockerSwarm::Communication` |
| Errores HTTP (404, 409, etc.) | Raise `DockerSwarm::NotFound`, `DockerSwarm::Conflict`, etc. |
| Timeouts | Raise `DockerSwarm::RequestTimeout` |
| Docker en mantenimiento | Raise `DockerSwarm::ServiceUnavailable` |

Ver tambien: [Manejo de Errores](errors.md) para la jerarquia completa de excepciones.
