# Dependencias consumidas — docker-swarm

> meta: artefacto · RFC-018 · generado arch-structure + enriquecido arch-enrich · anclado a `v0.9.0` · cobertura: superficie del Docker Engine API consumida por la gema (`api.rb` ENDPOINTS + `connection.rb`); §c/§e enriquecidas 1/1

## 1. Resumen

La gema consume **una** dependencia externa: el **Docker Engine API** (HTTP REST sobre Unix socket o TCP). Es el único servicio que invoca; toda la gema es un cliente tipado de esa API. Cliente propio = `DockerSwarm::Connection` (Excon) + `DockerSwarm::Api` (mapa de endpoints).

## 2. Cuerpo

### Docker Engine API

#### a. Identidad

| campo | valor |
|---|---|
| proveedor / servicio | Docker Engine API (daemon `dockerd`) |
| sub-tipo | **externo** (no es repo del fleet) |
| transporte | HTTP/REST sobre Unix socket (`unix:///var/run/docker.sock`, default) o TCP (`http://host:2375`) |
| cliente nuestro | `DockerSwarm::Connection` (Excon) + `DockerSwarm::Api` (`api.rb`) |
| auth | ninguna por default (socket local). TCP/TLS → fuera de alcance del cliente (no inyecta credenciales; 401 si el daemon las exige) |
| versión de API | v1.41 (referencia en los `@see` de los modelos; no se negocia explícitamente). **La gema no fija `?version=`** → el daemon sirve su versión **máxima**, así que la versión efectiva la decide cada host. Piso relevante: un Engine 20.10 topa en **v1.41**. Techo del parque: `unknown` (no derivable de este repo). Consecuencia en los logs: ver §b |
| ancla | doc oficial: <https://docs.docker.com/engine/api/v1.41/> |

#### b. Operaciones consumidas

Subset que la gema invoca, derivado de `Api::ENDPOINTS` (`api.rb:5-72`). `destino` = `método HTTP + path` (los `%<id>s` se interpolan en runtime).

| recurso | operación | destino | qué mandamos / esperamos |
|---|---|---|---|
| swarm | show | `GET swarm` | — / info del cluster (Hash) |
| system | info | `GET info` | — / Hash |
| system | version | `GET version` | — / Hash |
| system | up | `GET _ping` | — / `"OK"` |
| system | df | `GET system/df` | — / Hash de uso de disco |
| nodes | index | `GET nodes` | `?filters=` opcional / array |
| nodes | show | `GET nodes/%<id>s` | — / Hash |
| nodes | update | `POST nodes/%<id>s/update` | `?version=` + payload / — |
| nodes | destroy | `DELETE nodes/%<id>s` | — / — |
| tasks | index / show | `GET tasks`, `GET tasks/%<id>s` | `?filters=` / array \| Hash |
| tasks | logs | `GET tasks/%<id>s/logs` | `?stdout/stderr/...` / stream multiplexado (demux en el cliente) |
| services | index / show | `GET services`, `GET services/%<id>s` | `?filters=` / array \| Hash |
| services | create | `POST services/create` | payload (Spec aplanado) + header `X-Registry-Auth` (opcional, registry privado) / `{ID}` |
| services | update | `POST services/%<id>s/update` | `?version=` (+ `?registryAuthFrom=` opcional: `spec`\|`previous-spec`) + payload + header `X-Registry-Auth` (opcional; excluyente con `registryAuthFrom`) / — |
| services | destroy | `DELETE services/%<id>s` | — / — |
| services | logs | `GET services/%<id>s/logs` | `?stdout/stderr/...` / stream multiplexado (demux en el cliente) |
| configs | index / show / create / destroy | `GET configs`, `GET configs/%<id>s`, `POST configs/create`, `DELETE configs/%<id>s` | payload en create / `{ID}` |
| secrets | index / show / create / destroy | `GET secrets`, `GET secrets/%<id>s`, `POST secrets/create`, `DELETE secrets/%<id>s` | payload en create (`Data` filtrado en logs) / `{ID}` |
| networks | index / show / create / update / destroy | `GET/POST networks...`, `POST networks/%<id>s/update`, `DELETE networks/%<id>s` | payload / `{ID}` |
| volumes | index / show / create / destroy | `GET volumes`, `GET volumes/%<id>s`, `POST volumes/create`, `DELETE volumes/%<id>s` | payload / respuesta wrapped en `Volumes` |
| containers | index | `GET containers/json` | `?filters=` / array |
| containers | show | `GET containers/%<id>s/json` | — / Hash |
| containers | create | `POST containers/create` | `?name=` (query, NO en el body) + payload / `{Id}` |
| containers | start / stop | `POST containers/%<id>s/start`, `POST containers/%<id>s/stop` | — / — |
| containers | destroy | `DELETE containers/%<id>s` | — / — |
| containers | logs | `GET containers/%<id>s/logs` | `?stdout/stderr/...` / stream multiplexado (demux en el cliente) |
| images | index | `GET images/json` | — / array |
| images | show | `GET images/%<id>s/json` | — / Hash |
| images | pull | `POST images/create?fromImage=<ref>` | header `X-Registry-Auth` (opcional, registry privado) / stream NDJSON de progreso |
| images | destroy | `DELETE images/%<id>s` | — / — |

Serialización: request body no-String → JSON (`Content-Type: application/json`) vía `Middleware::RequestEncoder`; response `application/json` → `HashWithIndifferentAccess` recursivo vía `Middleware::ResponseJSONParser`.

**Streams de logs (`containers`/`services`/`tasks` → `logs`).** Sin TTY el Engine multiplexa: 8 bytes de cabecera por frame (1 tipo de stream · 3 de relleno en cero · 4 de tamaño big-endian). `Middleware::LogStreamDemuxer` los saca, así que `Loggable#logs` entrega texto limpio.

El `Content-Type` **no alcanza** para decidir. `application/vnd.docker.multiplexed-stream` existe **desde la API v1.42**; su entrada de changelog dice, textual:

> `GET /containers/{id}/attach`, `GET /exec/{id}/start`, `GET /containers/{id}/logs` `GET /services/{id}/logs` and `GET /tasks/{id}/logs` now set Content-Type header to `application/vnd.docker.multiplexed-stream` when a multiplexed stdout/stderr stream is sent to client, `application/vnd.docker.raw-stream` otherwise.

Antes de v1.42 ese valor no existía y un stream multiplexado viajaba igual como `application/vnd.docker.raw-stream`. Como la gema no fija `?version=`, un Engine 20.10 (tope v1.41) devuelve `raw-stream` **con** framing. Por eso el middleware, ante `raw-stream`, decide por la **forma del frame** —recorre el body entero y solo demultiplexa si la cadena de frames cierra de punta a punta— en vez de confiar en el header. Ante cualquier inconsistencia deja el body intacto.

> Anclaje: <https://docs.docker.com/reference/api/engine/version-history/> (entrada de v1.42).

#### d. Errores del proveedor → excepción nuestra

El daemon responde con status HTTP; `Middleware::ErrorHandler` los mapea a la jerarquía `DockerSwarm::Error`. La tabla completa status→excepción está en [`docs/errors/errors.md`](../errors/errors.md) §b (este artefacto **referencia**, no la redefine).

| condición del proveedor | excepción nuestra |
|---|---|
| status 4xx/5xx mapeado | la `DockerSwarm::Error::*` correspondiente (ver `docs/errors` §b) |
| status no-2xx no mapeado | `DockerSwarm::Error` (`HTTP <status>`) |
| socket caído / timeout de conexión (`Excon::Error::Socket`) | `DockerSwarm::Error::Communication` (preserva `cause`) |

#### c. Retry / idempotencia (semántica)

**Estructural** (anclado a `connection.rb:24-33`):

| aspecto | valor |
|---|---|
| métodos con retry | `get/head/put/delete/options` (`Connection::IDEMPOTENT_METHODS`) |
| reintentos | `max_retries` (default 3), solo en métodos idempotentes; POST/PATCH = 0 |
| errores reintentados | `Excon::Error::Socket`, `Excon::Error::Timeout` |
| backoff | ninguno — reintento inmediato (no se setea `retry_interval`) |

**Semántica:** la frontera idempotente/no-idempotente refleja la del Docker Engine API:

- `GET`/`DELETE`/`PUT` son seguros de reintentar: re-listar, re-borrar (404 → `nil` graceful) o re-actualizar produce el mismo estado final → la gema los reintenta automáticamente ante caída de socket.
- `POST create` (services/networks/volumes/configs/secrets/containers) **no** se reintenta: un replay tras fallo parcial podría crear un recurso duplicado (el daemon no deduplica por nombre en todos los recursos). El caller decide qué hacer si un `create` falla por `Communication`.
- `POST update`/`start`/`stop`/`restart` tampoco se reintentan (son POST); `update` además acarrea `?version=` → un replay con versión vieja daría 409 `Conflict`, no un duplicado.
- **Sin backoff** es aceptable acá: el socket Unix local rara vez está transitoriamente saturado; ante un daemon caído, 3 reintentos inmediatos fallan rápido y se propaga `Communication`.

#### e. Degradación (si la dependencia cae)

| escenario | comportamiento de la gema |
|---|---|
| socket caído / daemon no responde | tras `max_retries` (idempotentes) o inmediato (POST), levanta `DockerSwarm::Error::Communication` con el `Excon::Error::Socket` en `cause` |
| daemon devuelve 5xx | levanta la `Error::*` correspondiente (502/503/504) sin reintento HTTP |
| fallback / cola / circuit-breaker | **ninguno** — la gema es un cliente fino, fail-fast; no encola ni degrada |
| responsabilidad del consumidor | decidir reintento con backoff, fallback o propagación; la gema solo provee el error tipado |

- **SLA del proveedor:** n/a — el daemon Docker suele ser local (socket Unix) o de infraestructura propia; no hay SLA externo que documentar.
- **Sin estado degradado:** la gema no cachea ni mantiene estado entre llamadas; si el daemon cae, cada operación falla independientemente. No hay "modo degradado" que activar/desactivar.

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Versión de API = v1.41 | inferred | tomada de los `@see` de los modelos; la gema no fija `?version=` en la URL base ni negocia versión |
| `qué mandamos/esperamos` por operación | inferred | derivado del flujo de los concerns (`payload_for_docker`, `reload` tras create); el shape exacto del Spec lo fija Docker |

## 4. Cobertura y fronteras

- **Regla de dependencia directa:** solo se documenta lo que la gema invoca directo contra el daemon. Lo que Docker orqueste por debajo (scheduling de tasks en nodos, overlay networks) es concern del daemon, no de la gema.
- **Subset, no la API completa:** `Api::ENDPOINTS` cubre el subset que la gema expone; el Docker Engine API tiene endpoints (build, exec, plugins, `POST /auth`) que la gema **no** consume → fuera de alcance. Nota: la gema **sí** manda el header `X-Registry-Auth` (credencial opaca por-request); eso es distinto del endpoint `POST /auth` (login contra un registry), que sigue sin consumirse.
- **Auth de registry privado:** soportado como credencial opaca por-request — `Service.create`/`#update` (header `X-Registry-Auth`; `#update` además `registryAuthFrom` para reusar la del spec) e `Image.pull` (header `X-Registry-Auth`). La gema no mintea ni valida la credencial: la recibe base64url del caller y la pasa tal cual (`RegistryAuth` traduce a header/query). TLS/TCP para alcanzar el daemon sigue fuera de alcance (ver abajo).
- **TLS/TCP:** el cliente no gestiona certificados; un endpoint TCP con TLS mutuo queda fuera de alcance (resultará en `Unauthorized`/`Communication`).
