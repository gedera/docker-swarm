# DockerSwarm Expert

Skill de conocimiento completo sobre DockerSwarm. Consultame para cualquier pregunta sobre integración, arquitectura, API, errores y antipatrones.

## Glosario

**Base** — Clase ORM base que hereda de ActiveModel::Model. Provee accessors dinámicos PascalCase, `find`, `all`, `where`, `reload`, `payload_for_docker`. Todos los modelos heredan de ella.

**Concern** — Mixin ActiveSupport::Concern que agrega comportamiento CRUD a un modelo: Creatable (POST), Updatable (POST con Version.Index), Deletable (DELETE), Loggable (logs streaming), Inspectable (#inspect legible). **Nota:** Los atributos dinámicos en Inspectable deben invocarse con `send(:ID)` para evitar `NameError` por interpretación como constante.

**Middleware** — Capa Excon que procesa request/response: RequestEncoder (serialización body), ResponseJSONParser (parsing + indifferent access), ErrorHandler (status HTTP → excepción).

**Deep Indifferent Access** — Toda respuesta JSON se convierte recursivamente a `HashWithIndifferentAccess`, permitiendo acceso por symbol o string en cualquier nivel de anidamiento.

**Dynamic Accessor** — Cuando Docker devuelve un atributo nuevo (ej: `Spec`, `Status`), Base crea `attr_accessor` dinámicamente via `method_missing`. Se cachea en `defined_attributes` (Set) para no redefinir.

**Version.Index** — Mecanismo de Docker para updates atómicos. Updatable extrae `Version["Index"]` y lo envía como query param para evitar race conditions.

**LogHelper** — Módulo que formatea logs en KV (`key=value`) y enmascara campos sensibles matching `/password|token|api_key|auth|secret|data/i` → `[FILTERED]`.

## Arquitectura

### Responsabilidad core

ORM ligero compatible con ActiveModel para Docker Engine API. Comunica via Excon sobre Unix socket (default) o TCP. Todos los requests pasan por una cadena de middlewares.

### Mapa de componentes

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Modelo     │────>│   Api        │────>│  Connection   │
│  (Service,   │     │  (ENDPOINTS  │     │  (Excon +     │
│   Node...)   │     │   + request) │     │   Timeouts)   │
└──────────────┘     └──────────────┘     └──────────────┘
                                                │
                                                ▼
                                    ┌───────────────────────┐
                                    │   Middleware Stack     │
                                    │  RequestEncoder       │
                                    │  ResponseJSONParser   │
                                    │  ErrorHandler         │
                                    └───────────────────────┘
```

### Flujo en runtime

1. Modelo invoca `Api.request(action:, arguments:, query_params:, payload:)`.
2. Api formatea el path con `format()` y delega a `DockerSwarm.request`.
3. Connection crea/reutiliza cliente Excon singleton con middlewares.
4. RequestEncoder serializa body (JSON default, form-urlencoded, multipart).
5. Excon envía al Docker daemon (socket o TCP).
6. ResponseJSONParser parsea JSON y aplica `with_indifferent_access` recursivo.
7. ErrorHandler mapea status 4xx/5xx a excepciones tipadas.
8. Connection mide duración con `CLOCK_MONOTONIC` y loguea en KV.

### Decisiones de diseño

- **PascalCase fiel**: Los atributos mantienen el naming de Docker (`Spec`, `TaskTemplate`, `ContainerSpec`). No se transforman a snake_case.
- **Spec merging**: `assign_attributes` hace `deep_merge` cuando el atributo es `Spec` para no perder campos anidados en updates.
- **Singleton connection**: `@client ||= Excon.new(...)` — se reutiliza, se resetea al cambiar configuración.
- **Retries en Excon**: `idempotent: true` + `retry_errors: [Socket, Timeout]` con `max_retries` configurable.

## API Pública (resumen)

### Configuración

```ruby
DockerSwarm.configure do |config|
  config.socket_path     = "unix:///var/run/docker.sock"  # o http://host:port
  config.logger          = Logger.new($stdout)
  config.log_level       = Logger::INFO
  config.read_timeout    = 60.0    # segundos
  config.write_timeout   = 60.0
  config.connect_timeout = 10.0
  config.max_retries     = 3
end
```

### Operaciones comunes

```ruby
# Listar
DockerSwarm::Service.all
DockerSwarm::Service.all(label: ["app=web"])

# Buscar
service = DockerSwarm::Service.find("service_id")  # nil si no existe

# Crear
svc = DockerSwarm::Service.create(Name: "web", TaskTemplate: { ... })

# Actualizar (maneja Version.Index automáticamente)
service.update(Spec: { Replicas: 3 })

# Eliminar (graceful con 404)
service.destroy

# Logs
service.logs(stdout: 1, stderr: 1)

# Sistema
DockerSwarm::System.up       # ping
DockerSwarm::System.info     # daemon info
DockerSwarm::System.version  # versión Docker
DockerSwarm::System.df       # disk usage
DockerSwarm::Swarm.show      # info del cluster
```

Ver [API Detallada](references/api-detallada.md) para la referencia completa de todos los modelos.

## FAQ

### Como conecto a un Docker remoto por TCP?

```ruby
DockerSwarm.configure do |config|
  config.socket_path = "http://192.168.1.100:2375"
end
```
Connection detecta si empieza con `unix://` (socket) o no (TCP) y configura Excon.

### Por qué los atributos son PascalCase y no snake_case?

Docker Engine API usa PascalCase en todos sus JSON. La gema mantiene fidelidad 1:1 para evitar confusión al leer la documentación de Docker. Se accede igual: `service.Spec`, `node.Status`.

### Como filtro recursos con labels?

```ruby
DockerSwarm::Service.all(label: ["env=production", "app=web"])
DockerSwarm::Node.all(role: ["manager"])
```
Los filtros se serializan como JSON en el query param `filters` del Docker API.

### Como manejo errores de conexión?

```ruby
begin
  DockerSwarm::System.up
rescue DockerSwarm::Communication => e
  # Socket caído o inalcanzable
end
```
`Communication` envuelve errores de `Excon::Error::Socket`. Los retries se aplican automáticamente (`max_retries`).

### Puedo usar validaciones de ActiveModel?

Sí. Todos los modelos heredan de `ActiveModel::Model`. Podés agregar validaciones custom:

```ruby
service = DockerSwarm::Service.new(Name: "")
service.valid?  # usa validaciones ActiveModel
service.save    # retorna false si invalid?
```

## Antipatrones

### Transformar atributos a snake_case

```ruby
# MAL
service.task_template["container_spec"]

# BIEN
service.TaskTemplate["ContainerSpec"]
```
**Razón:** Docker API usa PascalCase. La gema mantiene fidelidad. Con indifferent access, podés usar strings o symbols, pero siempre PascalCase.

### Reemplazar Spec en vez de mergear

```ruby
# MAL — pierde campos existentes del Spec
service.update(Spec: { Mode: { Replicated: { Replicas: 5 } } })

# BIEN — mergear solo lo que cambia
service.update(Mode: { Replicated: { Replicas: 5 } })
```
**Razón:** `payload_for_docker` extrae contenido de Spec al root. Si pasás Spec completo, `assign_attributes` hace deep_merge, pero es más limpio pasar los campos directamente.

### Ignorar Version.Index en updates

```ruby
# MAL — update manual sin version
DockerSwarm.request(method: :post, path: "services/#{id}/update", body: payload)

# BIEN — usar el modelo, maneja version automáticamente
service.update(new_attrs)
```
**Razón:** Docker requiere `version` query param para updates atómicos. Updatable lo extrae de `self.Version["Index"]` automáticamente.

### No capturar errores específicos

```ruby
# MAL
begin
  service.destroy
rescue StandardError
  # tragarse todo
end

# BIEN
begin
  service.destroy
rescue DockerSwarm::NotFound
  # ya fue eliminado, ok
rescue DockerSwarm::Conflict => e
  # servicio en uso
end
```
**Razón:** La jerarquía de errores mapea cada status HTTP. Capturar errores específicos permite manejar cada caso.

## Errores

Los errores más comunes. Ver [Catálogo de Errores](references/errores.md) para la referencia completa.

| Excepción | Status | Causa típica |
|-----------|--------|--------------|
| `NotFound` | 404 | Recurso eliminado o ID incorrecto |
| `Conflict` | 409 | Nombre duplicado o recurso en uso |
| `Communication` | — | Socket caído o inalcanzable |
| `ServiceUnavailable` | 503 | Docker daemon reiniciando |

Todas heredan de `DockerSwarm::Error`. Se acceden como `DockerSwarm::NotFound` (alias) o `DockerSwarm::Error::NotFound`.

## Referencias

- [API Detallada](references/api-detallada.md) — Referencia completa de modelos, concerns y métodos
- [Catálogo de Errores](references/errores.md) — Todas las excepciones con causa y resolución
