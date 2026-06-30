# Dependencias consumidas — docker-swarm

> meta: artefacto · RFC-018 · generado arch-structure · anclado a `15bcd21` · cobertura: superficie del Docker Engine API consumida por la gema (`api.rb` ENDPOINTS + `connection.rb`); §c/§e sembradas `—` para arch-enrich

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
| versión de API | v1.41 (referencia en los `@see` de los modelos; no se negocia explícitamente) |
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
| tasks | logs | `GET tasks/%<id>s/logs` | `?stdout/stderr/...` / stream raw |
| services | index / show | `GET services`, `GET services/%<id>s` | `?filters=` / array \| Hash |
| services | create | `POST services/create` | payload (Spec aplanado) / `{ID}` |
| services | update | `POST services/%<id>s/update` | `?version=` + payload / — |
| services | destroy | `DELETE services/%<id>s` | — / — |
| services | logs | `GET services/%<id>s/logs` | `?stdout/stderr/...` / stream raw |
| configs | index / show / create / destroy | `GET configs`, `GET configs/%<id>s`, `POST configs/create`, `DELETE configs/%<id>s` | payload en create / `{ID}` |
| secrets | index / show / create / destroy | `GET secrets`, `GET secrets/%<id>s`, `POST secrets/create`, `DELETE secrets/%<id>s` | payload en create (`Data` filtrado en logs) / `{ID}` |
| networks | index / show / create / update / destroy | `GET/POST networks...`, `POST networks/%<id>s/update`, `DELETE networks/%<id>s` | payload / `{ID}` |
| volumes | index / show / create / destroy | `GET volumes`, `GET volumes/%<id>s`, `POST volumes/create`, `DELETE volumes/%<id>s` | payload / respuesta wrapped en `Volumes` |
| containers | index | `GET containers/json` | `?filters=` / array |
| containers | show | `GET containers/%<id>s/json` | — / Hash |
| containers | create | `POST containers/create` | payload / `{Id}` |
| containers | start / stop | `POST containers/%<id>s/start`, `POST containers/%<id>s/stop` | — / — |
| containers | destroy | `DELETE containers/%<id>s` | — / — |
| containers | logs | `GET containers/%<id>s/logs` | `?stdout/stderr/...` / stream raw |
| images | index | `GET images/json` | — / array |
| images | show | `GET images/%<id>s/json` | — / Hash |
| images | create | `POST images/create?fromImage=%<id>s` | — (pull; **sin** `X-Registry-Auth`) / stream |
| images | destroy | `DELETE images/%<id>s` | — / — |

Serialización: request body no-String → JSON (`Content-Type: application/json`) vía `Middleware::RequestEncoder`; response `application/json` → `HashWithIndifferentAccess` recursivo vía `Middleware::ResponseJSONParser`.

#### d. Errores del proveedor → excepción nuestra

El daemon responde con status HTTP; `Middleware::ErrorHandler` los mapea a la jerarquía `DockerSwarm::Error`. La tabla completa status→excepción está en [`docs/errors/errors.md`](../errors/errors.md) §b (este artefacto **referencia**, no la redefine).

| condición del proveedor | excepción nuestra |
|---|---|
| status 4xx/5xx mapeado | la `DockerSwarm::Error::*` correspondiente (ver `docs/errors` §b) |
| status no-2xx no mapeado | `DockerSwarm::Error` (`HTTP <status>`) |
| socket caído / timeout de conexión (`Excon::Error::Socket`) | `DockerSwarm::Error::Communication` (preserva `cause`) |

#### c. Retry / idempotencia (semántica)

| aspecto | valor |
|---|---|
| métodos con retry | `get/head/put/delete/options` (`Connection::IDEMPOTENT_METHODS`) — dato estructural |
| reintentos | `max_retries` (default 3), solo en métodos idempotentes; POST/PATCH = 0 |
| errores reintentados | `Excon::Error::Socket`, `Excon::Error::Timeout` (`connection.rb:28`) |
| idempotencia semántica / degradación | — |

#### e. Degradación (si la dependencia cae)

| escenario | comportamiento |
|---|---|
| (todos) | — |

> §c semántica + §e sembradas `—` (RFC-018). Lo completa `arch-enrich`. Lo estructural (qué métodos reintentan, con qué límite, qué errores Excon disparan retry) ya está arriba, derivado de `connection.rb`.

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Versión de API = v1.41 | inferred | tomada de los `@see` de los modelos; la gema no fija `?version=` en la URL base ni negocia versión |
| `qué mandamos/esperamos` por operación | inferred | derivado del flujo de los concerns (`payload_for_docker`, `reload` tras create); el shape exacto del Spec lo fija Docker |

## 4. Cobertura y fronteras

- **Regla de dependencia directa:** solo se documenta lo que la gema invoca directo contra el daemon. Lo que Docker orqueste por debajo (scheduling de tasks en nodos, overlay networks) es concern del daemon, no de la gema.
- **Subset, no la API completa:** `Api::ENDPOINTS` cubre el subset que la gema expone; el Docker Engine API tiene endpoints (build, exec, plugins, registry-auth) que la gema **no** consume → fuera de alcance.
- **Auth de registry privado:** `images/create` no inyecta `X-Registry-Auth` → pull de registries privados con auth no funciona vía la gema (usar `DockerSwarm.request` con headers manuales). Limitación conocida, ver `skill/SKILL.md`.
- **TLS/TCP:** el cliente no gestiona certificados; un endpoint TCP con TLS mutuo queda fuera de alcance (resultará en `Unauthorized`/`Communication`).
