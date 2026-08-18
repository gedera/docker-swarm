# Errores — docker-swarm

> meta: artefacto · RFC-020 · generado arch-structure + enriquecido arch-enrich · anclado a `8f2e1f7` · cobertura: excepciones públicas que la gema emite (`lib/docker_swarm/errors.rb` + `middleware/error_handler.rb` + `Image#raise_on_stream_error!`); política §c 16/16 enriquecida

## 1. Resumen

La gema traduce los status HTTP no-2xx del Docker Engine API a una jerarquía de excepciones Ruby tipadas, todas bajo `DockerSwarm::Error < StandardError`. El mapeo status→excepción vive en `Middleware::ErrorHandler`; los fallos de socket se envuelven en `Communication`. No hay payload propio (no es un servicio HTTP): el "shape" es la excepción Ruby + su `message`.

## 2. Cuerpo

### a. Inventario de excepciones públicas

Todas heredan de `DockerSwarm::Error` (que hereda de `StandardError`). Tres formas de acceso equivalentes: `DockerSwarm::NotFound`, `DockerSwarm::Error::NotFound`, `DockerSwarm::Errors::NotFound` (alias + `Errors.const_missing`).

| excepción | jerarquía base | qué la levanta |
|---|---|---|
| `Error` | `StandardError` | base de todas; el fallback `HTTP <status>` para status no mapeado; **y** el fallo de `Image.pull` cuando el stream de progreso reporta un frame `error`/`errorDetail` (Docker lo emite con **HTTP 200** → no lo agarra `ErrorHandler`; lo eleva `Image#raise_on_stream_error!`, `models/image.rb`) |
| `Error::BadRequest` | `Error` | status 400 (payload malformado) |
| `Error::Unauthorized` | `Error` | status 401 (TLS sin credenciales) |
| `Error::Forbidden` | `Error` | status 403 (permisos insuficientes, ej. swarm op en worker) |
| `Error::NotFound` | `Error` | status 404; capturada por `find`/`destroy` → `nil` |
| `Error::NotAcceptable` | `Error` | status 406 |
| `Error::RequestTimeout` | `Error` | status 408 |
| `Error::Conflict` | `Error` | status 409 (nombre duplicado o `Version.Index` stale) |
| `Error::UnprocessableEntity` | `Error` | status 422 (raised con el `body` crudo, no el `message`) |
| `Error::TooManyRequests` | `Error` | status 429 |
| `Error::InternalServerError` | `Error` | status 500 |
| `Error::BadGateway` | `Error` | status 502 |
| `Error::ServiceUnavailable` | `Error` | status 503 |
| `Error::GatewayTimeout` | `Error` | status 504 |
| `Error::Communication` | `Error` | socket caído/inalcanzable (`Excon::Error::Socket`); `Connection` la envuelve preservando el mensaje original |

### b. Códigos HTTP → excepción (por `Middleware::ErrorHandler`)

La gema **consume** HTTP, no lo expone. Esta tabla es el mapeo de respuesta-del-daemon → excepción-nuestra (`middleware/error_handler.rb:17-33`). El detalle de qué operación produce cada status está en el productor (Docker Engine API, ver [`docs/consumed/`](../consumed/docker-engine-api.md)).

| status | excepción | mensaje |
|---|---|---|
| 200–299 | — | pasa (no levanta) |
| 400 | `BadRequest` | `error_message(body)` |
| 401 | `Unauthorized` | `error_message(body)` |
| 403 | `Forbidden` | `error_message(body)` |
| 404 | `NotFound` | `error_message(body)` |
| 406 | `NotAcceptable` | `error_message(body)` |
| 408 | `RequestTimeout` | `error_message(body)` |
| 409 | `Conflict` | `error_message(body)` |
| 422 | `UnprocessableEntity` | `body` (crudo) |
| 429 | `TooManyRequests` | `error_message(body)` |
| 500 | `InternalServerError` | `error_message(body)` |
| 502 | `BadGateway` | `error_message(body)` |
| 503 | `ServiceUnavailable` | `error_message(body)` |
| 504 | `GatewayTimeout` | `error_message(body)` |
| otro no-2xx | `Error` | `"HTTP #{status}: #{error_msg}"` |

`error_message(body)`: si `body` es Hash → `body["message"] \|\| body["error"] \|\| body.to_json`; si no → `body.to_s` (`error_handler.rb:59-65`).

### d. Shape del payload de error

No aplica un shape propio tipo RFC 7807: la gema es un cliente, no un servidor. El "payload" que recibe el consumidor es la **excepción Ruby** con:

- `exception.class` — el tipo tipado (tabla §a).
- `exception.message` — el `message`/`error` del body de Docker (o el body crudo en 422), o `"Docker socket error: ..."` en `Communication`.
- `exception.cause` — en `Communication`, el `Excon::Error::Socket` original queda accesible (`connection.rb:47,61`).

### c. Política por error (retriable · backoff · idempotencia · acción)

> **Mecanismo (anclado a `connection.rb:24-33`):** el auto-retry de la gema opera **solo a nivel transporte** — reintenta `Excon::Error::Socket` y `Excon::Error::Timeout` en métodos idempotentes (`get/head/put/delete/options`), `max_retries=3`, **sin backoff** (reintento inmediato, no hay `retry_interval`). Los errores **HTTP 4xx/5xx NO se auto-reintentan**: una vez que llega una respuesta con status, `ErrorHandler` levanta y no hay retry. La columna "retriable" abajo es por tanto **recomendación al consumidor**, no comportamiento automático (salvo `Communication`).

> **Acción:** la gema **siempre loguea** el fallo (`request_failure`, nivel ERROR, `connection.rb:49`) y **propaga** (raise). No hay integración de observabilidad (Sentry/exis_ray) en la gema → `escalate`/`report` quedan al consumidor. Por eso la acción base de todas es **log + propagate**; la columna marca el matiz por error.

| excepción | retriable? (consumidor) | backoff | idempotencia requerida | acción / nota |
|---|---|---|---|---|
| `BadRequest` (400) | no | — | — | propagate — corregir payload |
| `Unauthorized` (401) | no | — | — | propagate — corregir credenciales/TLS |
| `Forbidden` (403) | no | — | — | propagate — op no permitida en este rol |
| `NotFound` (404) | no | — | — | `find`/`destroy` la absorben → `nil`; resto propagate |
| `NotAcceptable` (406) | no | — | — | propagate |
| `RequestTimeout` (408) | condicional | sí | sí (si POST) | retry solo en op idempotente; subir `read_timeout` |
| `Conflict` (409) | condicional | — | sí | si `Version.Index` stale → `reload` + reintentar `update`; si nombre duplicado → no retriable, propagate |
| `UnprocessableEntity` (422) | no | — | — | propagate — payload semánticamente inválido |
| `TooManyRequests` (429) | sí | sí | no | backoff + retry (rate limit del daemon) |
| `InternalServerError` (500) | condicional | sí | sí | retry en op idempotente; revisar payload (update sin `version` → 500) |
| `BadGateway` (502) | sí | sí | sí (si POST) | transitorio (proxy); retry seguro en op idempotente |
| `ServiceUnavailable` (503) | sí | sí | sí (si POST) | daemon reiniciando; retry con backoff |
| `GatewayTimeout` (504) | sí | sí | sí (si POST) | transitorio; retry en op idempotente |
| `Communication` (socket) | sí (auto) | no | sí (si POST) | la gema YA reintteta Socket/Timeout en métodos idempotentes (`max_retries`, sin backoff); en POST no reintenta → el caller decide |
| `Error` (pull stream, HTTP 200) | sí (consumidor) | sí | sí | `Image.pull` la eleva ante un frame `error`/`errorDetail` del stream; propagate. El pull es idempotente → el caller puede reintentar (ej. fallo transitorio de red/registry). Distinguir de un 404 **pre-stream** (imagen/registry inexistente o acceso denegado → no retriable) |

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| El "cuándo" de cada status (ej. 403 = swarm op en worker) refleja el comportamiento de Docker, no lógica de la gema | inferred | el mapeo es status→excepción genérico; la causa la fija el daemon. Notas tomadas de `skill/SKILL.md` |
| `UnprocessableEntity` recibe el `body` crudo (no `error_message`) a propósito (422 suele traer detalle estructurado) | declared | `error_handler.rb:25` — divergencia explícita del resto |
| §c columna "retriable" = recomendación al consumidor basada en semántica HTTP/Docker; la gema **no** auto-reintenta status HTTP (solo Socket/Timeout) | inferred | mecanismo anclado a `connection.rb`; la política por-status la confirma el humano contra el comportamiento real del daemon |
| 409 `Conflict` con `Version.Index` stale → patrón reload+retry | inferred | el `update` extrae `Version.Index` (`updatable.rb:9`); el reload-on-conflict es decisión del consumidor, no automática |

## 4. Cobertura y fronteras

- **Solo errores públicos:** estas excepciones cruzan la frontera de la gema hacia el consumidor. No hay excepciones internas rescatadas-y-tragadas que documentar (salvo `JSON::ParserError` en `ResponseJSONParser`, que se traga y retorna el body crudo — interno, no contrato).
- **Frontera con consumed (RFC-018):** este catálogo = lo que la gema **emite**. El mapeo "error del proveedor Docker → excepción nuestra" lo referencia [`docs/consumed/docker-engine-api.md`](../consumed/docker-engine-api.md) §d, que apunta acá.
- **Política §c:** enriquecida (recomendación al consumidor); el matiz por-status lo confirma el humano contra el comportamiento real del daemon (ver §3).
- **Validación de input del caller (`ArgumentError`, stdlib):** `RegistryAuth.resolve`/`validate!` (exclusión mutua `registry_auth`/`registry_auth_from` + enum del `from`), `Base#assign_attributes` (no-Hash) y `Container#update` (payload vacío tras descartar los `registry_auth`: el Engine lo aceptaría con `200 OK` sin aplicar nada, #39) elevan `ArgumentError` ante input inválido del caller — fail-fast, antes de tocar el daemon. Es contrato público de esas firmas (documentado en [`docs/interface/interface.md`](../interface/interface.md)), **no** parte de la jerarquía `DockerSwarm::Error` → por eso no está en §a/§c.
