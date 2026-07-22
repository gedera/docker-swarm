# Comportamiento — docker-swarm

> meta: artefacto · RFC-007 · generado dev-enrich · anclado a `29856f1` · cobertura: 10 flujos load-bearing (8 backfill inicial + 2 nuevos: auth de registry privado, `Image.pull` síncrono)

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
9. Auth de registry privado (`RegistryAuth.resolve` → `X-Registry-Auth` / `registryAuthFrom`)
10. `Image.pull` síncrono (stream NDJSON → error tipado → resultado explícito)

### No documentados (ausencia ≠ inexistencia, RFC-007)

- Reconexión / reapertura de socket Unix (Excon nativo, fuera de nuestra superficie).
- Flujo de configuración / boot (`DockerSwarm.configure`) — trivial, sin secuencia de interés.
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
    A["service.restart"] --> B["lee Spec.TaskTemplate.ForceUpdate"]
    B --> C["current = ForceUpdate o 0 si nil"]
    C --> D["update Spec: TaskTemplate: ForceUpdate: current+1"]
    D --> E["POST /services/id/update?version=X"]
    E --> F["Docker recrea tasks"]
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

### 3.9 Auth de registry privado (`X-Registry-Auth` / `registryAuthFrom`)

El caller pasa una credencial **opaca base64url** (`registry_auth`) y/o la fuente a reusar (`registry_auth_from`). `RegistryAuth.resolve` valida **antes** de la request (exclusión mutua + enum del `from`) y traduce a canales de transporte, sin tocar el payload ni el estado del modelo. La credencial se sanitiza en logs vía `LogHelper`. Aplica a `Service.create`/`#update` e `Image.pull`.

```mermaid
flowchart TD
    Start[Caller pasa registry_auth y/o registry_auth_from] --> Resolve[RegistryAuth.resolve valida y traduce]
    Resolve --> Both{ambos presentes?}
    Both -->|si| Err1[ArgumentError mutuamente excluyentes]
    Both -->|no| Enum{registry_auth_from en spec o previous-spec?}
    Enum -->|invalido| Err2[ArgumentError valor invalido]
    Enum -->|valido o ausente| Split[arma headers y query_params]
    Split --> Header[registry_auth va al header X-Registry-Auth]
    Split --> Query[registry_auth_from va a la query registryAuthFrom]
    Header --> Req[Api.request en create update o pull]
    Query --> Req
```

**Notas load-bearing:**
- La validación es **fail-fast local**: un caller que pasa ambos, o un `from` fuera de `spec`/`previous-spec`, corta con `ArgumentError` antes de tocar el Engine (no se deriva la ambigüedad a Docker).
- La credencial viaja **solo** por header/query — nunca en el payload ni en el estado del modelo. `LogHelper::SENSITIVE_KEYS` la enmascara en el wire-debug.

### 3.10 `Image.pull` síncrono (stream NDJSON → error tipado → resultado)

`Image.pull` es síncrono: consume el stream de progreso NDJSON hasta EOF, eleva error tipado ante un frame `error`/`errorDetail` (que Docker manda **con HTTP 200**), y solo tras terminación limpia devuelve un resultado explícito construido desde el stream — sin un `find` posterior.

```mermaid
sequenceDiagram
    actor Caller
    participant Image as DockerSwarm::Image
    participant RegAuth as RegistryAuth
    participant Api as DockerSwarm::Api
    participant Docker as Docker Engine

    Caller->>Image: pull(image_reference, registry_auth)
    Image->>RegAuth: resolve(registry_auth)
    RegAuth-->>Image: headers con X-Registry-Auth
    Image->>Api: request pull con fromImage y headers
    Api->>Docker: POST /images/create?fromImage=ref
    Docker-->>Image: stream NDJSON de progreso
    Image->>Image: parse_progress_stream + raise_on_stream_error!
    alt frame error o errorDetail
        Image-->>Caller: raise Error tipado
    else terminacion limpia
        Image->>Image: extract_digest desde frame Digest
        Image-->>Caller: status pulled + image_ref + digest
    end
```

**Notas load-bearing:**
- El middleware entrega el stream como `String` (multi-frame NDJSON) o `Hash` (frame único); `parse_progress_stream` normaliza ambos a lista de frames.
- El digest sale del frame `Digest: sha256:...` (el stream de pull **no** trae campo `aux` — verificado contra Docker 29.5.3), escaneando desde el final.
- Es un `POST` → **no** entra en la política de retries (ver flujo 3.5).

## 4. Cobertura y fronteras

- **Cobertura (RFC-007 backfill on-demand + incremental):** 8 flujos load-bearing en el backfill inicial + 2 agregados con el soporte de auth de registry privado (auth de registry privado, `Image.pull` síncrono) = 10. Esta gema es chica; el backfill completo era factible y se hizo, y a partir de ahí se acreta por PR.
- **Frontera con glosario:** términos (Service, Spec, Version.Index, etc.) viven en [`docs/glossary/glossary.md`](../glossary/glossary.md). Esta capa documenta secuencias, no significado.
- **Frontera con configuración:** `DockerSwarm.configure` es boot, no flujo de negocio. No se diagrama.
- **No localizable / fuera de alcance:**
  - Lógica interna de Excon (retry timing, socket pool) — vive en Excon, no se inventa diagrama.
  - Flujo de auth registry para `Image.create` — la gema **no implementa** `X-Registry-Auth` (gap, no flujo a documentar).
- **Cadencia incremental a partir de acá:** sólo se diagrama un flujo cuando un PR lo toca o agrega. No barrido retroactivo de legacy.
