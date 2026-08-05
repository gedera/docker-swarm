# Interfaz — docker-swarm

> meta: artefacto · RFC-004 · generado arch-structure · anclado a `v0.10.0` · cobertura: API Ruby pública de la gema (`lib/docker_swarm/**`); símbolos internos marcados en §4

## 1. Resumen

API Ruby pública de la gema. Entrypoint `DockerSwarm` (config + cliente HTTP). 11 modelos `ActiveModel`-compatibles heredan de `DockerSwarm::Base` y mezclan concerns (`Creatable`/`Updatable`/`Deletable`/`Loggable`). Atributos vía accessors dinámicos PascalCase (`method_missing`). Jerarquía de errores en `DockerSwarm::Error` (detalle en [`docs/errors/errors.md`](../errors/errors.md)).

## 2. Cuerpo

Proyección RBS-conceptual: `símbolo · tipo · nota` (raíz → profundidad → alfabético). Firmas aplanadas; el wire-schema de los atributos PascalCase no es estático (ver §4).

### Módulo raíz `DockerSwarm`

| símbolo | tipo | nota |
|---|---|---|
| `DockerSwarm` | módulo | namespace raíz |
| `DockerSwarm::VERSION` | constante | `"0.9.0"` (`version.rb`) |
| `DockerSwarm.configuration` | attr (r/w) | instancia de `Configuration`; lazy-init en `configure`/`connection` |
| `DockerSwarm.configure { \|config\| ... }` | método de módulo | crea/yields `Configuration`; aplica `log_level` al logger; resetea la conexión memoizada |
| `DockerSwarm.connection` | método de módulo | `Connection` memoizada (auto-`configure` si falta) |
| `DockerSwarm.request(options = {})` | método de módulo | delega en `connection.request`; entrypoint de bajo nivel (escape hatch para llamadas crudas) |

### `DockerSwarm::Configuration` (`configuration.rb`)

| símbolo | tipo | nota |
|---|---|---|
| `#socket_path` | attr (r/w) | default `"unix:///var/run/docker.sock"` |
| `#logger` | attr (r/w) | default `Logger.new($stdout)` |
| `#log_level` | attr (r/w) | default `Logger::INFO` |
| `#read_timeout` / `#read_timeout=` | attr (r) + setter | default `60.0`; setter castea `to_f` |
| `#write_timeout` / `#write_timeout=` | attr (r) + setter | default `60.0`; setter castea `to_f` |
| `#connect_timeout` / `#connect_timeout=` | attr (r) + setter | default `10.0`; setter castea `to_f` |
| `#max_retries` / `#max_retries=` | attr (r) + setter | default `3`; setter castea `to_i` |

Inventario completo de opciones: [`docs/config/configuracion.md`](../config/configuracion.md).

### `DockerSwarm::Base` (`base.rb`) — base de los modelos

`include ActiveModel::Model`, `include Concerns::Inspectable`.

| símbolo | tipo | nota |
|---|---|---|
| `.resource_name` | método de clase | `name.demodulize.downcase.pluralize`; override en `Swarm`/`System` |
| `.routes` | método de clase | `Api::ENDPOINTS[resource_name.to_sym]` |
| `.root_key` | método de clase | `nil` por default; override `"Volumes"` en `Volume` |
| `.defined_attributes` | método de clase | `Set` de accessors ya definidos (interno; cache de `method_missing`) |
| `.all(filters = {})` | método de clase | `GET index`; mapea a instancias; aplica `root_key`; `[]` si vacío |
| `.find(id)` | método de clase | `GET show`; `nil` si `Errors::NotFound` |
| `.where(filters)` | método de clase | alias de `all` |
| `.index_query_params` | método de clase | `%i[all force limit since before]` por default; override por modelo (`+ :status` en `Service`). Claves que viajan como **query params propios** del listado; **todo lo no declarado se serializa dentro del JSON de `?filters=`** — si tampoco es filtro válido del recurso, el Engine lo rechaza o lo ignora |
| `#initialize(attributes = {})` | método de instancia | `assign_attributes` si presente |
| `#assign_attributes(new_attributes)` | método de instancia | normaliza `Id`→`ID`; `deep_merge` del campo `Spec`; `ArgumentError` si no es Hash |
| `#attributes` | método de instancia | `instance_values` sin internos de ActiveModel |
| `#serializable_hash` / `#as_json` | método de instancia | == `attributes` |
| `#payload_for_docker` | método de instancia | descarta `ID/Version/CreatedAt/UpdatedAt`; aplana `Spec` al root |
| `#persisted?` | método de instancia | `ID` presente |
| `#id` | método de instancia | == `self.ID` |
| `#reload` | método de instancia | re-`find` por `id` y re-asigna |
| `#method_missing` / `#respond_to_missing?` | método de instancia | accessors dinámicos PascalCase (atributos del recurso Docker) |

### Concerns (`concerns/*.rb`)

| símbolo | tipo | nota |
|---|---|---|
| `Concerns::Creatable.create(attributes = {}, **opts)` | método de clase (mixin) | `new` + `save`; retorna la instancia. `opts` reservado `registry_auth:` (→ header `X-Registry-Auth`); el resto se pliega como atributos |
| `Concerns::Creatable#save(registry_auth: nil)` | método de instancia | `false` si `!valid?`; `update` si `persisted?`; si no `POST create` + `reload`. `registry_auth` viaja como header, nunca en el payload. Los `create_query_params` del modelo viajan por query string y se **excluyen** del payload |
| `Concerns::Creatable.create_query_params` | método de clase (mixin) | `[]` por default; override por modelo. Atributos que el Engine toma por query string en el `create` y **descarta en silencio** si van en el body |
| `Concerns::Creatable#query_params_for_docker` | método de instancia | los `create_query_params` seteados en esta instancia, con claves símbolo; `{}` si el modelo no declara ninguno |
| `Concerns::Updatable#update(new_attributes = {}, **opts)` | método de instancia | extrae `Version.Index`; `false` si `!valid?`; `POST update` con `?version=`. `opts` reservado `registry_auth:` (header) / `registry_auth_from:` (query `registryAuthFrom`, `spec`\|`previous-spec`, excluyente con `registry_auth`); el resto se pliega como atributos |
| `Concerns::Deletable.destroy(id)` | método de clase (mixin) | `DELETE destroy`; `nil` si `Errors::NotFound` |
| `Concerns::Deletable#destroy` | método de instancia | delega en `.destroy(self.ID)` |
| `Concerns::Loggable#logs(query_params = { stdout: 1, stderr: 1 })` | método de instancia | `GET logs`; retorna **texto ya demultiplexado** (sin los 8 bytes de cabecera por frame) — el demux lo hace `Middleware::LogStreamDemuxer`, el consumidor no ve el framing. Un stream de TTY (sin framing) pasa intacto |
| `Concerns::Inspectable#inspect` | método de instancia | render legible (ID/Name/Version/Spec) |

### Modelos (`models/*.rb`)

| símbolo | tipo | concerns + métodos propios |
|---|---|---|
| `DockerSwarm::Service` | clase < Base | Creatable, Updatable, Deletable, Loggable; `#restart` (incrementa `TaskTemplate.ForceUpdate`); `create`/`update` aceptan `registry_auth:` (+ `update`: `registry_auth_from:`) para auth de registry privado; `.index_query_params` agrega `:status` → `where(status: true)` puebla `ServiceStatus` (`RunningTasks`/`DesiredTasks`/`CompletedTasks`), único lugar donde el Engine publica el deseado de un service `global` |
| `DockerSwarm::Node` | clase < Base | Updatable, Deletable (sin `create`: los nodos se unen fuera de la gema) |
| `DockerSwarm::Task` | clase < Base | Loggable (read-only; generadas por el orquestador) |
| `DockerSwarm::Container` | clase < Base | Creatable, Deletable, Loggable; `#start`, `#stop`; `.create_query_params == %w[name]` (el Engine toma el nombre por query string — en el body lo descarta en silencio y el container nace con nombre aleatorio). El `create` **no** es gap intencional desde ADR-025 cláusula 1 |
| `DockerSwarm::Image` | clase < Base | Deletable + `.pull(image_reference, registry_auth: nil)`. **NO** es Creatable (`Image.create` retirado sin alias). `.pull` = pull explícito síncrono: consume el stream NDJSON hasta EOF, eleva `DockerSwarm::Error` ante frame `error`/`errorDetail`, retorna `{ status: :pulled, image_ref:, digest? }` (sin `find` posterior) |
| `DockerSwarm::Network` | clase < Base | Creatable, Updatable, Deletable |
| `DockerSwarm::Volume` | clase < Base | Creatable, Deletable; `.root_key = "Volumes"` (respuesta wrapped) |
| `DockerSwarm::Config` | clase < Base | Creatable, Deletable (sin `update`: recrear) |
| `DockerSwarm::Secret` | clase < Base | Creatable, Deletable (sin `update`); `Data` filtrado en logs |
| `DockerSwarm::Swarm` | clase < Base | `.resource_name = "swarm"`; `.show` (singleton, info del cluster) |
| `DockerSwarm::System` | clase < Base | `.resource_name = "system"`; `.info`, `.version`, `.up`, `.df` (singleton) |

### Superficie de bajo nivel / soporte

| símbolo | tipo | nota |
|---|---|---|
| `DockerSwarm::Api::ENDPOINTS` | constante (frozen Hash) | mapa `recurso → {operación → {method, path}}` |
| `DockerSwarm::Api.request(action:, arguments: {}, query_params: {}, payload: nil)` | método de clase | formatea el `path` y delega en `DockerSwarm.request` |
| `DockerSwarm::Connection.new(socket_path, logger)` | clase | cliente Excon (Unix socket o TCP); `#request`, `#socket_path`, `#logger` |
| `DockerSwarm::Connection::IDEMPOTENT_METHODS` | constante | `%i[get head put delete options]` (los únicos con retry) |
| `DockerSwarm::LogHelper.format_kv(payload)` | método de módulo | formatea KV + masking de claves sensibles |
| `DockerSwarm::LogHelper::SENSITIVE_KEYS` | constante (Regexp) | `password\|pass\|...\|\bdata\b` |
| `DockerSwarm::RegistryAuth.resolve(registry_auth:, registry_auth_from:)` | método de módulo | traduce las opciones de auth a `[headers, query_params]` (`X-Registry-Auth` / `registryAuthFrom`); valida exclusión mutua + enum antes de la request. Usado por `Image.pull` / `#save` / `#update`; la credencial nunca toca payload ni estado del modelo |
| `DockerSwarm::RegistryAuth::{HEADER, QUERY, FROM_VALUES}` | constantes | `"X-Registry-Auth"` · `:registryAuthFrom` · `%w[spec previous-spec]` |
| `DockerSwarm::Error` + subclases + aliases + `DockerSwarm::Errors` | clases/módulo | jerarquía de errores — detalle en [`docs/errors/errors.md`](../errors/errors.md) |
| `DockerSwarm::Middleware::{RequestEncoder, LogStreamDemuxer, ResponseJSONParser, ErrorHandler}` | clases | middlewares Excon; públicos por require pero de uso interno (ver §4) |
| `DockerSwarm::Middleware::LogStreamDemuxer::{MULTIPLEXED_CONTENT_TYPE, RAW_CONTENT_TYPE, HEADER_SIZE, STREAM_TYPES}` | constantes | `"application/vnd.docker.multiplexed-stream"` · `"application/vnd.docker.raw-stream"` · `8` · `[0, 1, 2]` |

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| `Connection`, `Api` y los `Middleware::*` son de uso **interno** (un consumidor normal usa los modelos, no estas clases) | inferred | son `public` en Ruby; no hay marca `@api private`. `DockerSwarm.request`/`Api` son el escape-hatch documentado en `skill/SKILL.md` |
| `.defined_attributes` es interno (cache de `method_missing`), no superficie de consumo | inferred | público pero sin uso externo plausible |
| Los atributos PascalCase (`service.Spec`, `service.Version`, …) son la superficie real de datos, pero su set depende de la respuesta del Docker Engine API | declared | `method_missing` define accessors on-demand; el shape lo fija Docker, no la gema |

## 4. Cobertura y fronteras

- **Wire-schema de atributos:** los modelos no declaran atributos estáticos — se materializan dinámicamente desde el JSON de Docker (`method_missing`). El shape de `Spec`/`TaskTemplate`/etc. es el del Docker Engine API v1.41, **fuera de este repo** (doc oficial Docker). `unspecified` acá a propósito.
- **`interface` vs `operaciones` (RFC-003):** esta gema NO expone superficie HTTP/CLI/eventos propia → `docs/api/operaciones` es `n/a`. Su superficie pública ES esta interfaz Ruby. Lo que la gema *consume* (Docker Engine API) vive en [`docs/consumed/`](../consumed/docker-engine-api.md).
- **Errores:** la jerarquía `DockerSwarm::Error` se cataloga en [`docs/errors/errors.md`](../errors/errors.md); acá solo se referencia.
- **Símbolos internos:** `Connection`, `Api`, `Middleware::*`, `Base.defined_attributes` se listan por completitud pero no son API de consumo recomendada; un cambio en ellos no rompe el contrato del consumidor típico (que usa los modelos).
- **Significado de negocio** de cada modelo/término → [`docs/glossary/glossary.md`](../glossary/glossary.md); secuencias → [`docs/behavior/behavior.md`](../behavior/behavior.md).
