# Pruebas y Mocking

Al integrar `docker-swarm` en tu aplicación, querrás evitar que los tests realicen llamadas reales al socket de Docker de tu máquina o del entorno de CI.

## 🧪 Estrategia de Mocking

La forma más efectiva de testear tu aplicación es mockear el punto de entrada principal: `DockerSwarm::Api.request` o el método `DockerSwarm.request`.

### Ejemplo con RSpec

Si tu código utiliza un modelo de la gema:

```ruby
# app/services/deployer.rb
class Deployer
  def scale_service(id, replicas)
    service = DockerSwarm::Service.find(id)
    service.update(Spec: { Mode: { Replicated: { Replicas: replicas } } })
  end
end

# spec/services/deployer_spec.rb
RSpec.describe Deployer do
  it "escala el servicio correctamente" do
    # Mockear la búsqueda del servicio
    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:show])
    ).and_return({ "ID" => "svc-123", "Version" => { "Index" => 1 }, "Spec" => {} })

    # Mockear la actualización del servicio
    expect(DockerSwarm::Api).to receive(:request).with(
      hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:update])
    ).and_return(true)

    deployer = Deployer.new
    expect(deployer.scale_service("svc-123", 5)).to be true
  end
end
```

---

## 🛠️ Mockear la Conexión (`Excon`)

Si prefieres un nivel más bajo, puedes mockear `DockerSwarm.request` directamente:

```ruby
allow(DockerSwarm).to receive(:request).and_return({ "Status" => "OK" })
```

---

## 🏗️ Configuración de Tests

En tu `spec_helper.rb` o `rails_helper.rb`, asegúrate de configurar la gema con valores ficticios para evitar accidentes:

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

---

## 🔍 Resumen de Pruebas

| Qué testear | Cómo mockear |
| :--- | :--- |
| **Modelos (ORM)** | Mockea `DockerSwarm::Api.request` |
| **Llamadas API** | Mockea `DockerSwarm.request` |
| **Errores de Red** | Haz que el mock lance `DockerSwarm::Errors::Communication` |
| **Errores 404/409** | Haz que el mock lance `DockerSwarm::Errors::NotFound` |
