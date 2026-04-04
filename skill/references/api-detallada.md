# API Detallada

Referencia completa de modelos, concerns, middleware y métodos públicos de DockerSwarm.

## Modelos — Tabla de capacidades

| Modelo | Creatable | Updatable | Deletable | Loggable | Extra |
|--------|-----------|-----------|-----------|----------|-------|
| Service | x | x | x | x | Ciclo de vida completo |
| Node | | x | x | | Miembros del cluster, no se crean |
| Task | | | | x | Read-only, generados por services |
| Container | | | x | x | `#start`, `#stop` |
| Network | x | x | x | | CRUD completo |
| Volume | x | | x | | `root_key = "Volumes"` |
| Config | x | | x | | Configuración del cluster |
| Secret | x | | x | | Datos sensibles |
| Image | x | | x | | Pull/removal |
| Swarm | | | | | `.show` (estático) |
| System | | | | | `.info`, `.version`, `.up`, `.df` |

## Base — Métodos de clase

```ruby
# Listar todos (con filtros opcionales)
# @param filters [Hash] Filtros Docker (label:, name:, id:, role:, etc.)
# @return [Array<Model>]
Model.all(filters = {})

# Alias de .all
Model.where(filters)

# Buscar por ID (retorna nil si 404)
# @param id [String]
# @return [Model, nil]
Model.find(id)

# Nombre del recurso pluralizado (ej: "services", "nodes")
Model.resource_name

# Endpoints del modelo desde Api::ENDPOINTS
Model.routes
```

### Filtros soportados

```ruby
# Filtros Docker se serializan como JSON en query param `filters`
DockerSwarm::Service.all(label: ["app=web"], name: ["my-service"])
DockerSwarm::Container.all(status: ["running"])
DockerSwarm::Node.all(role: ["manager"])

# Parámetros globales (no van en filters)
DockerSwarm::Image.all(all: true)         # incluir intermedias
DockerSwarm::Container.all(limit: 10)     # limitar resultados
```

## Base — Métodos de instancia

```ruby
# ID del recurso
# @return [String]
model.id

# Hash de atributos (excluye internos de ActiveModel)
# @return [Hash]
model.attributes

# Recarga desde Docker API
# @return [self]
model.reload

# Prepara payload para Docker (excluye ID, Version, CreatedAt, extrae Spec)
# @return [Hash]
model.payload_for_docker

# Persistido? (tiene ID)
# @return [Boolean]
model.persisted?

# Inspección legible: #<DockerSwarm::Service ID: abc, Name: web, Image: nginx>
model.inspect

# Serialización
model.as_json
model.serializable_hash
```

## Concern: Creatable

Incluido en: Service, Network, Volume, Config, Secret, Image.

```ruby
# Crear y persistir
# @param attributes [Hash] Atributos PascalCase
# @return [Model] instancia (con ID si exitoso)
Model.create(attributes)

# Persistir instancia nueva (o delegar a update si persisted?)
# @return [Boolean] false si validación falla
model.save
```

Flujo interno de `save`: `valid?` → `Api.request(:create, payload_for_docker)` → asigna ID de response → `reload`.

## Concern: Updatable

Incluido en: Service, Node, Network.

```ruby
# Actualizar recurso persistido
# @param new_attributes [Hash] Atributos a mergear
# @return [Boolean] false si validación falla
model.update(new_attributes = {})
```

Flujo interno: `assign_attributes` (deep_merge en Spec) → `valid?` → `Api.request(:update, id:, version: Version["Index"], payload:)`.

**Importante:** El query param `version` se extrae automáticamente de `self.Version["Index"]`. Sin esto, Docker rechaza el update con 500.

## Concern: Deletable

Incluido en: Service, Node, Container, Network, Volume, Config, Secret, Image.

```ruby
# Eliminar por instancia
# @return [true, nil] nil si ya no existía (404 graceful)
model.destroy

# Eliminar por ID (class method)
# @return [true, nil]
Model.destroy(id)
```

## Concern: Loggable

Incluido en: Service, Task, Container.

```ruby
# Obtener logs del recurso
# @param query_params [Hash] stdout:, stderr:, follow:, tail:, since:, timestamps:
# @return [String] Raw log stream
model.logs(query_params = { stdout: 1, stderr: 1 })
```

## Container — Métodos específicos

```ruby
container = DockerSwarm::Container.find("container_id")

# Iniciar contenedor detenido
# @return [Boolean]
container.start

# Detener contenedor en ejecución
# @return [Boolean]
container.stop
```

## System — Métodos estáticos

```ruby
# Ping al daemon
# @return [String] "OK"
DockerSwarm::System.up

# Información del daemon
# @return [Hash] (Containers, Images, Driver, MemoryLimit, etc.)
DockerSwarm::System.info

# Versión de Docker
# @return [Hash] (Version, ApiVersion, Os, Arch, etc.)
DockerSwarm::System.version

# Uso de disco
# @return [Hash] (LayersSize, Images, Containers, Volumes)
DockerSwarm::System.df
```

## Swarm — Método estático

```ruby
# Información del cluster Swarm
# @return [Hash] (ID, Version, Spec, JoinTokens, etc.)
DockerSwarm::Swarm.show
```

## Volume — Particularidad

Volume sobreescribe `root_key` porque Docker envuelve la respuesta en `{"Volumes": [...]}`:

```ruby
class Volume < Base
  def self.root_key = "Volumes"
end
```

## Api — Bajo nivel

```ruby
# Request directo al Docker API
# @param action [Hash] {method:, path:} desde ENDPOINTS
# @param arguments [Hash] Interpolación en path (id:)
# @param query_params [Hash] Query string
# @param payload [Hash, nil] Body del request
DockerSwarm::Api.request(action:, arguments: {}, query_params: {}, payload: nil)
```

### Endpoints registrados

Todos definidos en `Api::ENDPOINTS` como Hash frozen:

| Recurso | Acciones |
|---------|----------|
| swarm | show |
| system | info, version, up, df |
| nodes | index, show, update, destroy |
| tasks | index, show, logs |
| services | index, show, create, update, destroy, logs |
| configs | index, show, create, destroy |
| secrets | index, show, create, destroy |
| networks | index, show, create, update, destroy |
| volumes | index, show, create, destroy |
| containers | index, show, create, start, stop, destroy, logs |
| images | index, show, create, destroy |

## Middleware Stack

Orden de ejecución en Excon:

1. **Excon defaults** (Retry, Instrumentor, etc.)
2. **Excon::Middleware::RedirectFollower**
3. **RequestEncoder** — Serializa body: JSON (default), form-urlencoded, multipart. Detecta por Content-Type header.
4. **ResponseJSONParser** — Parsea JSON si Content-Type incluye `application/json`. Aplica `with_indifferent_access` recursivo (Hash y Array de Hashes).
5. **ErrorHandler** — Status 4xx/5xx → excepción tipada. Loguea `business_error` antes de raise.

## Configuración

| Opción | Tipo | Default | Descripción |
|--------|------|---------|-------------|
| `socket_path` | String | `unix:///var/run/docker.sock` | Socket Unix o URL TCP |
| `logger` | Logger | `Logger.new($stdout)` | Logger para KV output |
| `log_level` | Integer | `Logger::INFO` | Nivel de log (se aplica al logger) |
| `read_timeout` | Float | `60.0` | Timeout lectura (segundos) |
| `write_timeout` | Float | `60.0` | Timeout escritura (segundos) |
| `connect_timeout` | Float | `10.0` | Timeout conexión (segundos) |
| `max_retries` | Integer | `3` | Reintentos en Socket/Timeout errors |
