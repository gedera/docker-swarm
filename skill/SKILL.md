---
name: docker-swarm
description: >-
  ORM y cliente API Ruby para Docker Swarm. Expone las primitivas del Docker
  Engine (Service, Node, Task, Container, Network, Volume, Config, Secret,
  Swarm, System, Image) como modelos ActiveModel con CRUD, control de
  concurrencia optimista (Version.Index), retries seguros por método HTTP,
  logging KV con masking de secrets y jerarquía de errores tipada. ACTIVAR
  cuando el caller necesita orquestar Docker desde Ruby — listar/crear/
  actualizar/eliminar recursos del cluster, leer logs de services/tasks/
  containers, hacer health-check del daemon (System.up/info/df), filtrar por
  labels, o capturar errores tipados de Docker (Conflict/NotFound/
  Communication). NO activar para builds de imágenes (no implementado), pull
  con auth de registry privado (no implementado), o flujos que no son
  Swarm (Docker Compose, raw containers).
triggers:
  - "DockerSwarm::"
  - "docker-swarm gem"
  - "Docker Engine API desde Ruby"
  - "Service.create / Service.update / Service.restart"
  - "Container.start / Container.stop"
  - "logs de un servicio Docker"
  - "Version.Index"
---

# docker-swarm — Skill

## Qué es / cuándo usar

Gema Ruby que provee ORM `ActiveModel`-compatible sobre Docker Engine API. Cliente HTTP `Excon` directo (Unix socket o TCP). Usá esta dep para orquestación programática de Docker Swarm: lifecycle de recursos, logs, health checks y observabilidad.

No es:
- Build/compose tool — no construye imágenes, no parsea `docker-compose.yml`.
- Driver Kubernetes — sólo Swarm.

## Contrato resumido (piso mínimo)

### Configuración

```ruby
DockerSwarm.configure do |config|
  config.socket_path     = "unix:///var/run/docker.sock"  # o "http://host:2375"
  config.logger          = Logger.new($stdout)
  config.log_level       = Logger::INFO
  config.read_timeout    = 60.0
  config.write_timeout   = 60.0
  config.connect_timeout = 10.0
  config.max_retries     = 3
end
```

Defaults son razonables: en local sin TLS, no necesitás bloque `configure`.

### Símbolos públicos por modelo

| Modelo | Class methods | Instance methods | Notas |
|---|---|---|---|
| `Service` | `all(filters)`, `find(id)`, `where(filters)`, `create(attrs)` | `update(attrs)`, `restart`, `destroy`, `logs(query)`, `reload`, `persisted?`, `id` | CRUD completo + force-recreate de tasks |
| `Node` | `all(filters)`, `find(id)`, `where(filters)` | `update(attrs)`, `destroy` | No `create` (los nodos se unen fuera de la gema) |
| `Task` | `all(filters)`, `find(id)`, `where(filters)` | `logs(query)`, `reload` | Read-only (generados por orquestador) |
| `Container` | `all(filters)`, `find(id)`, `where(filters)` | `start`, `stop`, `destroy`, `logs(query)` | **No `create`** (gap conocido, fuera F1) |
| `Image` | `all(filters)`, `find(id)`, `create(attrs)` | `destroy` | `create` = pull. **No soporta `X-Registry-Auth`** (registries privados con auth no funcionan) |
| `Network` | `all(filters)`, `find(id)`, `create(attrs)` | `update(attrs)`, `destroy` | CRUD completo |
| `Volume` | `all(filters)`, `find(id)`, `create(attrs)` | `destroy` | No `update` (Docker no lo soporta). Respuesta wrapped vía `root_key = "Volumes"` |
| `Config` | `all(filters)`, `find(id)`, `create(attrs)` | `destroy` | No `update` — recrear |
| `Secret` | `all(filters)`, `find(id)`, `create(attrs)` | `destroy` | No `update`. `Data` se filtra en logs (LogHelper) |
| `Swarm` | `.show` | — | Singleton, sólo info del cluster |
| `System` | `.info`, `.version`, `.up`, `.df` | — | Singleton, health/observabilidad |

Detalle por símbolo en [`docs/glossary/glossary.md`](docs/glossary/glossary.md). Secuencias de operación en [`docs/behavior/behavior.md`](docs/behavior/behavior.md).

### Operaciones típicas

```ruby
# Listar con filtros (serializa como JSON en query param `filters`)
DockerSwarm::Service.all(label: ["env=production"])
DockerSwarm::Node.all(role: ["manager"])
DockerSwarm::Container.all(status: ["running"])

# Lookup graceful (nil si 404)
service = DockerSwarm::Service.find("svc-id")  # => Service | nil

# Crear (auto-reload tras POST para hidratar Spec/Version completos)
svc = DockerSwarm::Service.create(
  Name: "web",
  TaskTemplate: { ContainerSpec: { Image: "nginx:latest" } }
)

# Update atómico (Version.Index extraído automáticamente)
service.update(Mode: { Replicated: { Replicas: 3 } })

# Force-recreate de tasks (equivalente a `docker service update --force`)
service.restart

# Destroy graceful (nil si 404)
service.destroy

# Logs raw
service.logs(stdout: 1, stderr: 1)

# Health check
DockerSwarm::System.up        # => "OK" si daemon responde
```

### Jerarquía de errores

Todas heredan de `DockerSwarm::Error`. Tres formas de acceso equivalentes: `DockerSwarm::NotFound`, `DockerSwarm::Error::NotFound`, `DockerSwarm::Errors::NotFound`.

| Excepción | Status | Cuándo |
|---|---|---|
| `BadRequest` | 400 | Payload malformado |
| `Unauthorized` | 401 | TLS sin credenciales |
| `Forbidden` | 403 | Permisos insuficientes (ej: swarm op en worker) |
| `NotFound` | 404 | Recurso inexistente (capturado por `find`/`destroy`) |
| `NotAcceptable` | 406 | Headers Accept incompatibles (raro) |
| `RequestTimeout` | 408 | Daemon tardó (subí `read_timeout`) |
| `Conflict` | 409 | Nombre duplicado o `Version.Index` stale |
| `UnprocessableEntity` | 422 | Payload semánticamente inválido |
| `TooManyRequests` | 429 | Rate limiting |
| `InternalServerError` | 500 | Bug Docker o update sin `version` query param |
| `BadGateway` | 502 | Proxy entre cliente y daemon falló |
| `ServiceUnavailable` | 503 | Daemon reiniciando |
| `GatewayTimeout` | 504 | Proxy timeout |
| `Communication` | — | Socket caído / inalcanzable. `cause` mantiene el `Excon::Error` original |

## Gotchas / breaking

- **PascalCase fiel.** Los atributos NO se transforman: `service.Spec`, `service.TaskTemplate`, `service.Version` — no `snake_case`. Indifferent access soportado: `service.Spec[:Name]` ≡ `service.Spec["Name"]`.
- **`Version.Index` obligatorio en updates** (Service/Node/Network). La gema lo extrae automático de `self.Version["Index"]`. Si construís el request por afuera (`DockerSwarm.request`), tenés que pasarlo vos.
- **Retries automáticos sólo en métodos seguros** (GET/HEAD/PUT/DELETE/OPTIONS). POST/PATCH **no** reintentan para evitar duplicados — si el socket se cae durante un `create`, el caller decide qué hacer. Ver §3.5 de `docs/behavior/behavior.md`.
- **`Spec` se mergea con `deep_merge` en updates**, no se reemplaza. Pasale sólo los campos que cambian: `service.update(Mode: {...})`, no `service.update(Spec: {...completo})`.
- **`assign_attributes` muta antes de validar.** Si `update` falla por `valid?` o por el API, la instancia local quedó mutada. Hacé `reload` si necesitás estado limpio.
- **`Container.create` no existe** en la gema (gap intencional F1). Si necesitás crear containers standalone, usá `DockerSwarm.request(method: :post, path: "containers/create", ...)` directo.
- **Pull con registry privado no soportado.** `Image.create` no inyecta header `X-Registry-Auth`. Para registries privados, fallback a `DockerSwarm.request` con headers manuales.
- **`destroy` es graceful con 404** (retorna `nil`), no con 409. Si el recurso está en uso, `Conflict` se propaga.
- **Logs sensibles enmascarados** automáticamente: keys matching `password|pass|passwd|secret|token|api_key|auth|\bdata\b` → `[FILTERED]`. `\bdata\b` evita filtrar `metadata`/`database`.

## Testing

Mockear `DockerSwarm::Api.request`:

```ruby
expect(DockerSwarm::Api).to receive(:request).with(
  hash_including(action: DockerSwarm::Api::ENDPOINTS[:services][:show])
).and_return({ "ID" => "svc-1", "Spec" => { "Name" => "web" }, "Version" => { "Index" => 1 } })

service = DockerSwarm::Service.find("svc-1")
```

Para `create`: mockear **dos** llamadas (POST + show de reload). Para errores: `and_raise(DockerSwarm::NotFound)` etc.

## Integración (Rails)

```ruby
# config/initializers/docker_swarm.rb
DockerSwarm.configure do |config|
  config.socket_path = ENV.fetch("DOCKER_URL", "unix:///var/run/docker.sock")
  config.logger      = Rails.logger
  config.log_level   = Rails.logger.level
end
```

Logs salen en formato KV (`component=docker_swarm.connection event=request_success ...`) compatible con parsers estructurados.

## Índice de artefactos

- [`docs/glossary/glossary.md`](docs/glossary/glossary.md) — definición de términos (primitivas Docker + conceptos internos).
- [`docs/behavior/behavior.md`](docs/behavior/behavior.md) — secuencias load-bearing (create+reload, update+Version, retry-policy, error-mapping, etc.).
- [`docs/config/configuracion.md`](docs/config/configuracion.md) — inventario de configuración runtime (7 opciones del bloque `configure`, sin env vars, ninguna secreta). El bloque de arriba es el resumen; shape/defaults/consumidores en el detalle.
- `docs/data/` — `n/a` (gema sin DB).
- `docs/api/`, `docs/interface/`, `docs/topology/` — F2 declaradas, **no implementadas**. El contrato resumido de arriba reside **transitoriamente** acá (RFC-008 §2 coexistencia transitoria con destino pendiente).

## Versionado del contrato

Este SKILL.md viaja version-locked con el release de la gema (`gemspec.files` incluye `skill/**/*`). Para consumir desde otro proyecto: el agente lee `Gem.loaded_specs["docker-swarm"].gem_dir + "/skill/SKILL.md"`. Links relativos del paquete del release; no `HEAD`/branch.
