# Errores — docker-swarm

> meta: artefacto · RFC-020 · generado arch-structure · anclado a `15bcd21` · cobertura: excepciones públicas que la gema emite (`lib/docker_swarm/errors.rb` + `middleware/error_handler.rb`); política (§c) sembrada `—` para arch-enrich

## 1. Resumen

La gema traduce los status HTTP no-2xx del Docker Engine API a una jerarquía de excepciones Ruby tipadas, todas bajo `DockerSwarm::Error < StandardError`. El mapeo status→excepción vive en `Middleware::ErrorHandler`; los fallos de socket se envuelven en `Communication`. No hay payload propio (no es un servicio HTTP): el "shape" es la excepción Ruby + su `message`.

## 2. Cuerpo

### a. Inventario de excepciones públicas

Todas heredan de `DockerSwarm::Error` (que hereda de `StandardError`). Tres formas de acceso equivalentes: `DockerSwarm::NotFound`, `DockerSwarm::Error::NotFound`, `DockerSwarm::Errors::NotFound` (alias + `Errors.const_missing`).

| excepción | jerarquía base | qué la levanta |
|---|---|---|
| `Error` | `StandardError` | base de todas; también el fallback `HTTP <status>` para status no mapeado |
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

### c. Política (retriable / backoff / idempotencia / acción)

| excepción | política |
|---|---|
| (todas) | — |

> Sembrado `—` (RFC-020 §c). Lo completa `arch-enrich`. Dato estructural relacionado ya verificable: el retry automático lo decide el **método HTTP** (`Connection::IDEMPOTENT_METHODS = get/head/put/delete/options`, `max_retries=3`), no la clase de error; POST/PATCH no reintentan (ver [`docs/consumed/`](../consumed/docker-engine-api.md) §c y `docs/behavior/`).

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| El "cuándo" de cada status (ej. 403 = swarm op en worker) refleja el comportamiento de Docker, no lógica de la gema | inferred | el mapeo es status→excepción genérico; la causa la fija el daemon. Notas tomadas de `skill/SKILL.md` |
| `UnprocessableEntity` recibe el `body` crudo (no `error_message`) a propósito (422 suele traer detalle estructurado) | declared | `error_handler.rb:25` — divergencia explícita del resto |

## 4. Cobertura y fronteras

- **Solo errores públicos:** estas excepciones cruzan la frontera de la gema hacia el consumidor. No hay excepciones internas rescatadas-y-tragadas que documentar (salvo `JSON::ParserError` en `ResponseJSONParser`, que se traga y retorna el body crudo — interno, no contrato).
- **Frontera con consumed (RFC-018):** este catálogo = lo que la gema **emite**. El mapeo "error del proveedor Docker → excepción nuestra" lo referencia [`docs/consumed/docker-engine-api.md`](../consumed/docker-engine-api.md) §d, que apunta acá.
- **Política §c:** pendiente de `arch-enrich`.
