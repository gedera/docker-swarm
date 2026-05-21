# Comportamiento — docker-swarm

> meta: artefacto · RFC-007 · generado dev-enrich · anclado a `a4e3129` · cobertura: backfill on-demand inicial (8 flujos load-bearing)

## 1. Resumen

Flujos de ejecución load-bearing de `docker-swarm`: cómo se materializan en runtime las operaciones CRUD, el control de concurrencia optimista de Docker, la política de retries post-fix correctness, y el mapeo de errores. Render Mermaid sequenceDiagram/flowchart por flujo.

## 2. Cobertura declarada

### Documentados (8)

1. `Service.create` + reload
2. `Service.update` con `Version.Index`
3. `Service.restart` (force update)
4. `Model.destroy` (graceful 404)
5. Política de retries por método HTTP
6. Error mapping (HTTP status → excepción tipada)
7. `Container.start` / `Container.stop`
8. `Loggable#logs` streaming

### No documentados (ausencia ≠ inexistencia, RFC-007)

- Reconexión / reapertura de socket Unix (Excon nativo, fuera de nuestra superficie).
- Flujo de configuración / boot (`DockerSwarm.configure`) — trivial, sin secuencia de interés.
- Pull de imágenes con autenticación de registry (`X-Registry-Auth`) — **no implementado** en la gema (gap conocido).
- `Container.create` — **no implementado** en F1 (intencional, ver glossary).

## 3. Flujos

### 3.1 `Service.create` + reload

Crear un Service implica un POST seguido de un reload automático para hidratar la instancia con la respuesta completa de Docker (el endpoint `create` sólo devuelve `ID`).

```mermaid
sequenceDiagram
    actor Caller
    participant Service as DockerSwarm::Service
    participant Api as DockerSwarm::Api
    participant Conn as Connection
    participant Docker as Docker Engine

    Caller->>Service: Service.create(Name:, TaskTemplate:)
    Service->>Service: new(attrs) → valid?
    Service->>Api: request(:create, payload: payload_for_docker)
    Api->>Conn: request(method: :post, path: services/create, body:)
    Conn->>Docker: POST /services/create
    Docker-->>Conn: 201 { ID: "abc" }
    Conn-->>Service: { ID: "abc" }
    Service->>Service: self.ID = "abc"
    Service->>Api: request(:show, arguments: { id: "abc" })
    Api->>Conn: request(method: :get, path: services/abc)
    Conn->>Docker: GET /services/abc
    Docker-->>Conn: 200 { ID, Spec, Version, ... }
    Conn-->>Service: full payload
    Service-->>Caller: hydrated Service instance
```

**Notas load-bearing:**
- `valid?` corre antes del POST. Si falla, `save` retorna `false` sin tocar el API.
- El POST no se reintenta automáticamente: ver §3.5 (retry policy).
- El reload usa `find` interno; si Docker devuelve 404 entre create+show (caso extremo), el reload no se realiza y la instancia queda sólo con `ID`.

### 3.2 `Service.update` con `Version.Index`

Updates atómicos sobre Service/Node/Network requieren enviar el `Version.Index` actual como query param. Sin él, Docker rechaza con 500. La gema lo extrae automáticamente de `self.Version["Index"]`.

```mermaid
sequenceDiagram
    actor Caller
    participant Model as Service/Node/Network
    participant Api
    participant Docker as Docker Engine

    Caller->>Model: model.update(Mode: { Replicated: { Replicas: 3 } })
    Model->>Model: assign_attributes(new_attrs)  -- Spec deep_merge si aplica
    Model->>Model: valid?
    Model->>Api: request(:update, id:, query: { version: Version.Index }, payload:)
    Api->>Docker: POST /services/abc/update?version=42
    alt version coincide
        Docker-->>Api: 200 OK
        Api-->>Model: success
        Model-->>Caller: true
    else version stale
        Docker-->>Api: 500 update out of sequence
        Api->>Api: ErrorHandler → raise InternalServerError
        Api-->>Caller: DockerSwarm::Error::InternalServerError
    end
```

**Notas load-bearing:**
- `assign_attributes` muta el estado local **antes** de validar/enviar. Si el update falla, la instancia queda mutada (gotcha conocido, ver SKILL.md).
- `Spec` se mergea con `deep_merge`; otros atributos top-level se asignan directo.
- El update **no** hace reload automático (a diferencia de `create`). El caller llama `reload` si necesita el `Version.Index` nuevo.

### 3.3 `Service.restart` (force update)

Reinicio sin downtime equivalente a `docker service update --force`: incrementa `ForceUpdate` del `TaskTemplate` para que Docker recree todas las tasks.

```mermaid
flowchart LR
    A[service.restart] --> B[lee Spec.TaskTemplate.ForceUpdate]
    B --> C[current = ForceUpdate || 0]
    C --> D[update Spec: TaskTemplate: ForceUpdate: current+1]
    D --> E[POST /services/id/update?version=X]
    E --> F[Docker recrea tasks]
```

**Notas load-bearing:**
- Usa el flujo §3.2 internamente — hereda Version.Index, retry-policy y error-mapping.
- Si `Spec` o `TaskTemplate` no existen aún (instancia nueva sin reload), `current = 0`.

### 3.4 `Model.destroy` (graceful 404)

DELETE con tolerancia a 404: si el recurso ya fue eliminado, `destroy` retorna `nil` en vez de raise.

```mermaid
sequenceDiagram
    actor Caller
    participant Model
    participant Api
    participant Docker

    Caller->>Model: model.destroy
    Model->>Api: request(:destroy, id:)
    Api->>Docker: DELETE /services/abc
    alt recurso existe
        Docker-->>Api: 200 OK
        Api-->>Model: true
        Model-->>Caller: true
    else 404 (ya eliminado)
        Docker-->>Api: 404 Not Found
        Api->>Api: ErrorHandler → raise NotFound
        Model->>Model: rescue Errors::NotFound
        Model-->>Caller: nil
    end
```

**Notas load-bearing:**
- Tanto `Model.destroy(id)` (class method) como `model.destroy` (instance) capturan `NotFound`.
- 409 (`Conflict` — recurso en uso) **no** se captura; el caller debe manejarlo si aplica.

### 3.5 Política de retries por método HTTP

Post-fix correctness (PR #3): los retries automáticos sólo aplican a métodos seguros. POST/PATCH no reintentan para evitar duplicados.

```mermaid
flowchart TD
    Req[Connection#request<br/>method, path, body] --> Class{IDEMPOTENT_METHODS<br/>incluye method?}
    Class -- get/head/put/delete/options --> Safe[idempotent: true<br/>retries: max_retries]
    Class -- post/patch/otro --> Write[idempotent: false<br/>retries: 0]
    Safe --> Excon[Excon.request<br/>retry on Socket/Timeout]
    Write --> ExconNoRetry[Excon.request<br/>sin retry]
```

**Notas load-bearing:**
- Si el socket se cierra durante la lectura de la respuesta de un `services/create`, **no** se replica — la instancia queda en error y el caller decide.
- `max_retries` (default 3) sólo afecta lecturas/idempotentes.

### 3.6 Error mapping (status → excepción)

`ErrorHandler` interpreta status HTTP 4xx/5xx y emite excepción tipada de la jerarquía `DockerSwarm::Error`.

```mermaid
flowchart TD
    Resp[Response status, body] --> Range{status range}
    Range -- 200-299 --> Pass[pass to next middleware]
    Range -- 4xx/5xx --> Log[log business_error<br/>KV format]
    Log --> Map{status}
    Map -- 400 --> BadRequest
    Map -- 401 --> Unauthorized
    Map -- 403 --> Forbidden
    Map -- 404 --> NotFound
    Map -- 406 --> NotAcceptable
    Map -- 408 --> RequestTimeout
    Map -- 409 --> Conflict
    Map -- 422 --> UnprocessableEntity
    Map -- 429 --> TooManyRequests
    Map -- 500 --> InternalServerError
    Map -- 502 --> BadGateway
    Map -- 503 --> ServiceUnavailable
    Map -- 504 --> GatewayTimeout
    Map -- otro --> GenericError[Error HTTP N]
```

**Notas load-bearing:**
- Antes de raise, `ErrorHandler` emite un evento `business_error` en formato KV con `status`, `message`, `method`, `path`. Permite diagnosticar sin abrir backtrace.
- Errores de red (no HTTP) se mapean a `DockerSwarm::Error::Communication` en `Connection#request`.
- El mensaje de la excepción viene del body parseado: prefiere `body["message"]`, luego `body["error"]`, luego el body completo.

### 3.7 `Container.start` / `Container.stop`

Operaciones específicas sin payload (POST a endpoint dedicado).

```mermaid
sequenceDiagram
    actor Caller
    participant Container as DockerSwarm::Container
    participant Api
    participant Docker

    Caller->>Container: container.start
    Container->>Api: request(:start, id:)
    Api->>Docker: POST /containers/abc/start
    Docker-->>Api: 204 No Content
    Api-->>Container: ""
    Container-->>Caller: true
```

Mismo patrón para `stop`. POST sin body → no se reintenta automáticamente (§3.5).

### 3.8 `Loggable#logs` streaming

Obtención de logs raw para Service/Task/Container.

```mermaid
sequenceDiagram
    actor Caller
    participant Model as Service/Task/Container
    participant Api
    participant Docker

    Caller->>Model: model.logs(stdout: 1, stderr: 1, follow: 0)
    Model->>Api: request(:logs, id:, query: { stdout:, stderr:, follow: })
    Api->>Docker: GET /services/abc/logs?stdout=1&stderr=1
    Docker-->>Api: 200 raw stream (text/plain)
    Api-->>Model: raw body
    Model-->>Caller: String
```

**Notas load-bearing:**
- El body se devuelve sin parseo (no es JSON; `ResponseJSONParser` lo respeta porque Content-Type no es `application/json`).
- `follow: 1` mantiene la conexión abierta — el caller debe manejar el stream/timeout.

## 4. Cobertura y fronteras

- **Cobertura inicial (RFC-007 backfill on-demand):** 8 flujos load-bearing documentados. Esta gema es chica; el backfill completo es factible y se hace ahora.
- **Frontera con glosario:** términos (Service, Spec, Version.Index, etc.) viven en [`docs/glossary/glossary.md`](../glossary/glossary.md). Esta capa documenta secuencias, no significado.
- **Frontera con configuración:** `DockerSwarm.configure` es boot, no flujo de negocio. No se diagrama.
- **No localizable / fuera de alcance:**
  - Lógica interna de Excon (retry timing, socket pool) — vive en Excon, no se inventa diagrama.
  - Flujo de auth registry para `Image.create` — la gema **no implementa** `X-Registry-Auth` (gap, no flujo a documentar).
- **Cadencia incremental a partir de acá:** sólo se diagrama un flujo cuando un PR lo toca o agrega. No barrido retroactivo de legacy.
