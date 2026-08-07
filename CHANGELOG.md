# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Correcciones
- **`Container.where(since:)` / `where(before:)` filtran de verdad, y `size` llega al Engine** (#35). Las dos claves son **filtros** de `GET /containers/json` según el spec v1.41 (`ContainerList`), no query params, pero el default de `Base.index_query_params` las ruteaba a la URL: el Engine **las ignoraba y devolvía la lista sin filtrar, sin ningún error** — resultado incorrecto silencioso. Y `size` (query param propio, pide el tamaño de los archivos del container) viajaba dentro de `?filters=` como filtro inválido. `Container` ahora declara `%i[all limit size]` — @Pslp
  - **Mismo bug en `Image`**, con la misma evidencia: `/images/json` declara `all` y `digests` como query params propios y lista `before`/`since` entre sus filtros. `Image` ahora declara `%i[all digests]`.
  - **Cambio de comportamiento observable:** `Container.where(since: id)` antes devolvía **todos** los containers y ahora filtra. Si algún consumidor compensaba filtrando en Ruby, el resultado no cambia; si dependía de recibir la lista completa, cambia.
  - `Base` **no** se toca: su default (`%i[all force limit since before]`) no matchea el listado de ningún recurso, pero limpiarlo convertiría no-ops silenciosos en filtros inválidos hacia el Engine para los 7 modelos que hoy no declaran lista propia. Queda como decisión aparte.

## [0.10.0] — 2026-08-05

### Nuevas funcionalidades
- **`Service.where(status: true)` puebla `ServiceStatus`** (#22). `status` es un query param **propio** de `GET /services` (Engine API ≥ v1.41), no un filtro, y hasta ahora la gema no tenía forma de mandarlo: caía en el JSON de `?filters=`, donde el Engine no lo acepta como filtro de `/services`. Con esto cada elemento del listado trae `ServiceStatus` (`RunningTasks` · `DesiredTasks` · `CompletedTasks`), que es el **único** lugar donde el Engine publica el deseado de un service en modo `global` — un replicado lo expone en `Spec.Mode.Replicated.Replicas`, pero para un global ese campo no existe. Sin `DesiredTasks` un global corriendo en 2 de 3 nodos elegibles es indistinguible de uno sano: solo se detecta el caso extremo de cero tasks — @Pslp
  - La whitelist de query params del listado sale a `Base.index_query_params` (default `%i[all force limit since before]`, **override por modelo**), y `Service` la extiende con `:status`. Se resuelve así, y **no** subiendo `status` a `Base`, porque en `/containers/json` `status` **sí** es un filtro válido (`running`, `exited`, …): globalizarlo lo sacaría del `?filters=` y rompería `Container.where(status: "running")`. Hay un spec de regresión que lo fija.
  - **Compatible hacia atrás:** sin pasar `status` el listado no cambia. Y **degrada en silencio**: la gema no fija `?version=`, así que en un Engine por debajo de v1.41 el parámetro se ignora sin error y `ServiceStatus` llega ausente → el consumidor tiene que tolerar `nil`, no hay señal de "no soportado".
  - **Trampa del consumidor:** en un service `global` recién creado `DesiredTasks` vale **0** — el Engine publica los contadores antes de evaluar los nodos elegibles y lo completa ~1s después (medido contra un Engine `1.54`). En esa ventana `RunningTasks == DesiredTasks == 0`, así que comparar los dos números para decidir salud miente; `DesiredTasks.positive?` va como precondición. Documentado en `docs/consumed/` y `skill/SKILL.md`.

## [0.9.0] — 2026-08-03

### Nuevas funcionalidades
- `Container` pasa a incluir `Concerns::Creatable`: la gema ya puede **crear** containers, no solo operar los existentes. El nombre viaja por **query string** (`POST /containers/create?name=`), que es donde el Engine lo espera — en el body lo descarta en silencio y responde `201`, dejando el container con nombre aleatorio. `Concerns::Creatable` gana `create_query_params` (default `[]`, override por modelo; `Container` declara `%w[name]`) y `query_params_for_docker`; `save` los manda en la URL y los excluye del payload. Implementa ADR-025 cláusula 1 — @gedera

### Breaking changes
- **`logs` devuelve texto demultiplexado.** Sin TTY el Engine enmarca cada fragmento con 8 bytes de cabecera (tipo de stream · relleno · tamaño big-endian); el nuevo `Middleware::LogStreamDemuxer` los saca, así que `Loggable#logs` entrega texto limpio en `Container`, `Service` y `Task`. **Cambia el valor de retorno** para cualquier consumidor que hoy reciba el body crudo. Un stream sin framing (TTY) pasa intacto. Implementa ADR-025 cláusula 3 — @gedera
  - El dispatch **no** se decide solo por `Content-Type`: `application/vnd.docker.multiplexed-stream` existe desde la **API v1.42**, y antes un stream multiplexado viajaba igual como `application/vnd.docker.raw-stream`. Como la gema no fija `?version=`, un Engine que tope en v1.41 devuelve `raw-stream` **con** framing. Ante `raw-stream` el middleware valida la **forma del frame** y solo demultiplexa si la cadena cierra de punta a punta; ante cualquier inconsistencia devuelve el body intacto. Registrado en **ADR-027**, que corrige un dato de apoyo del §Alternativas de ADR-025 **sin** superseder su Decisión.

### Seguridad
- **`LogHelper.sanitize` redacta los secretos que viajan como `"CLAVE=VALOR"` en `Env`** (#24). Antes redactaba solo por **clave de hash**: un String caía al `else` y pasaba intacto, y el `Env` de un `ContainerSpec` es un **array de strings** `"CLAVE=VALOR"` donde el nombre del secreto vive *dentro* del elemento. Como `"Env"` tampoco matchea `SENSITIVE_KEYS`, el valor de todo secreto pasado por variable de entorno **se logueaba entero en `request_success` — camino feliz, nivel INFO** — en cada create/update de un service. Se agrega `redact_kv_string` y una rama `when String`: si la parte izquierda matchea `SENSITIVE_KEYS` se reemplaza el valor y **se conserva el nombre** (saber qué secreto apareció es diagnóstico útil; su valor no). El regex usa `[^=]+` a la izquierda para no partir en un `=` del valor (base64, URLs) y `/m` para valores multilínea. Afecta a **todas** las versiones anteriores — @Pslp
  - **Hueco declarado, no cubierto por este fix:** `private_key` **no está** en `SENSITIVE_KEYS`, así que un PEM con ese nombre sigue saliendo en claro (hay un spec que lo fija como comportamiento conocido). Ampliar la lista va aparte: cambia la redacción para todos los consumidores.

### Otros cambios
- `spec.homepage` del gemspec pasa a `https://github.com/sequre/docker-swarm` (#27): el repo se transfirió de la cuenta personal `gedera` a la org `sequre`. De ahí derivan los cuatro metadata URIs (`source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `documentation_uri`), así que desde esta versión apuntan a la ubicación nueva. Las versiones ya publicadas conservan la URL anterior — las salva el redirect de GitHub — @gedera

## [0.8.0] — 2026-07-22

### Nuevas funcionalidades
- `Service.create`/`Service#update`: soporte de autenticación de registry privado — `registry_auth` viaja en el header `X-Registry-Auth` y `registry_auth_from` (`spec`|`previous-spec`) en la query `registryAuthFrom` del update; mutuamente excluyentes y validados antes del request. La credencial nunca toca el payload ni el estado del modelo (helper `RegistryAuth`) — @Pslp
- `Image.pull`: pull explícito síncrono (consume el stream NDJSON hasta EOF, eleva error tipado ante `error`/`errorDetail`, devuelve `{status: :pulled, image_ref:, digest?}` sin `find`; el digest sale del frame `Digest: sha256:…`, verificado contra Docker 29.5.3). **Capacidad sin consumidor activo hoy**: el deploy de imágenes privadas se autentica vía `Service.create` (X-Registry-Auth distribuido a los nodos por Swarm), no por pull explícito. `Image.pull` queda disponible para un futuro requerimiento (pre-pull / warm-cache) — @Pslp

### Breaking changes
- `Image` deja de incluir `Creatable`: se retira `Image.create` (roto y sin consumidores) en favor de `Image.pull`. `Image` conserva `Deletable` y el listado — @Pslp

### Seguridad
- `LogHelper` sanitiza recursivamente los headers de autenticación (`X-Registry-Auth`, `Authorization`) para no filtrar credenciales en logs de wire-debug — @Pslp

## [0.7.2] — 2026-06-29

### Documentación
- Regenerar la capa de configuración conforme RFC-012 (`docs/config/configuracion.md`): inventario de las 7 opciones runtime del bloque `configure`, sin env vars, ninguna secreta — @Gabriel
- Reindexar `skill/SKILL.md` §4 para apuntar al nuevo artefacto de configuración — @Gabriel
- Instaurar `AGENTS.md` (stanza "Mapa de conocimiento") y normalizar `skills.yml` al molde fleet — @Gabriel

### Mejoras internas
- Bump excon 1.4.2 → 1.5.0 — @Gabriel

## [0.7.1] — 2026-05-29

### Correcciones
- `Updatable#update`: captura `Version.Index` **antes** de `assign_attributes` para evitar que un payload con versión desactualizada pise el índice real del nodo y provoque `update out of sequence` en Docker — @Pablo

## [0.7.0] — 2026-05-21

### Breaking changes
- `Connection#request`: retries automáticos sólo en métodos seguros (GET/HEAD/PUT/DELETE/OPTIONS). POST/PATCH ya **no** reintentan para evitar recursos duplicados ante caída de socket — @Gabriel
- `Base#assign_attributes`: rama muerta que aceptaba no-Hash ahora levanta `ArgumentError` con mensaje claro — @Gabriel
- Ruby floor: `>= 3.2.0` (antes `>= 2.7.0`), alineado con `activesupport` 8.1 — @Gabriel

### Correcciones
- `Connection#request`: clasificación de errores por `is_a?(DockerSwarm::Error)` en vez de `class.name.include?`, evita falsos positivos con clases externas — @Gabriel
- `LogHelper::SENSITIVE_KEYS`: `data` ahora se matchea con `\b` para no filtrar `metadata`, `database` u otras claves legítimas — @Gabriel

### Documentación
- Re-estructura completa bajo skills `dev-*` (RFC-001/007/008/009/010): nuevos `docs/glossary/glossary.md` (20 términos) y `docs/behavior/behavior.md` (8 flujos load-bearing con Mermaid). `README.md` minimal-control y `skill/SKILL.md` con frontmatter, contrato resumido, version-lock — @Gabriel
- Eliminados docs ad-hoc pre-estándar (`docs/{api,configuration,errors,models,testing}.md` y `skill/references/`) — @Gabriel

### Mejoras internas
- CI: tests unitarios en `bundle exec rspec --tag ~type:integration` para que el build verde sea significativo sin Docker disponible — @Gabriel
- Gemspec: `metadata` con `changelog_uri`/`bug_tracker_uri`/`documentation_uri`/`rubygems_mfa_required` version-locked; `LICENSE`, `CHANGELOG.md` y `docs/**/*` incluidos en `spec.files` para que viajen con el release — @Gabriel
- `LICENSE` (MIT) agregado al repo — @Gabriel
- Removido `debug_docker.rb` del repo (artefacto de desarrollo) — @Gabriel

## [0.6.0] - 2026-04-08

### Nuevas funcionalidades
- `Service#restart`: reinicia un servicio incrementando `ForceUpdate` en el `TaskTemplate`, equivalente a `docker service update --force` — @Gabriel

## [0.5.4] - 2026-04-07

### Correcciones
- `Inspectable`: todos los atributos deben usar `send(:attr)` para invocar métodos dinámicos — @Gabriel

## [0.5.3] - 2026-04-07

### Mejoras internas
- `Inspectable` ahora muestra todos los atributos (ID, Name, CreatedAt, UpdatedAt, Version, Spec) — @Gabriel

## [0.5.2] - 2026-04-07

### Correcciones
- Fix en `Inspectable`: usar `send(:ID)` en vez de `ID` directamente para evitar `NameError` por interpretación como constante — @Gabriel

## [0.5.1] - 2026-04-06

### Mejoras internas
- Refactor de logs en `Connection`: cambio de `duration_ms` a `duration_s` y de `status` a `http_status` para alinearse con estándares de observabilidad — @Gabriel
- Precisión de duración mejorada usando segundos con 4 decimales — @Gabriel
- Reestructuración de `skills.yml` para soportar variables de entorno en agentes y nuevas skills — @Gabriel

## [0.5.0] - 2026-04-04

### Nuevas funcionalidades
- Skill de conocimiento empaquetada (`skill/`) para consumo via `skill-manager sync` — @Gabriel
- Helper de testing documentado (`DockerSwarmHelpers`) con `stub_docker_find` y `stub_docker_list` — @Claude

### Mejoras internas
- README reescrito con instalación, más ejemplos de uso, y sección Documentación linkeando a `docs/` — @Claude
- `docs/testing.md` reescrito: mockeo de CRUD, errores, helper reutilizable — @Claude
- `docs/errors.md` completado con errores faltantes (NotAcceptable 406, RequestTimeout 408, BadGateway 502) — @Claude
- Cross-references bidireccionales entre todos los docs — @Claude
- Centralización de logging en `LogHelper` con masking de campo `Data` para Secret/Config — @Gabriel
- Gemspec actualizado para empaquetar `skill/**/*` en el `.gem` — @Claude

## [0.4.0] - 2026-03-31

### Nuevas funcionalidades
- Dependabot configurado para actualizaciones semanales de gemas y mensuales de GitHub Actions — @Gabriel
- Integración de `rubocop-rails-omakase` y verificación RuboCop en CI — @Gabriel
- Tests de infraestructura robustos para `Connection`, `Configuration` y Middlewares — @Gabriel
- Documentación YARD en todos los modelos y componentes core — @Gabriel
- Concern `Inspectable` para inspección legible en consola (ID, Name, Image) — @Gabriel

### Mejoras internas
- Memoización de accessors en `Base` para optimizar procesamiento de recursos — @Gabriel
- Refactor de logs a `Concerns::Loggable` para DRY en Service, Task y Container — @Gabriel
- Branch default renombrado de `master` a `main` — @Gabriel

### Correcciones
- Casting automático de timeouts y retries para prevenir `TypeError` con ENV variables — @Gabriel
- Orden de carga interno reorganizado para resolver issues de inicialización — @Gabriel

## [0.3.0] - 2026-03-31

### Nuevas funcionalidades
- Timeouts y retries configurables: `read_timeout`, `write_timeout`, `connect_timeout`, `max_retries` — @Gabriel
- `RequestEncoder` soporta `application/x-www-form-urlencoded` y `multipart/form-data` — @Gabriel
- `ResponseJSONParser` aplica `with_indifferent_access` recursivo en Arrays — @Gabriel

## [0.2.0] - 2026-03-31

### Nuevas funcionalidades
- Logging estructurado KV (`component`, `event`, `source`, `duration_ms`) estándar Wispro — @Gabriel
- Reloj monotónico para medición precisa de duración de requests — @Gabriel
- Masking automático de claves sensibles en logs — @Gabriel
- Soporte para Unix sockets y HTTP/TCP via `socket_path` — @Gabriel
- `Network.update` implementado — @Gabriel
- `log_level` configurable en runtime — @Gabriel
- Error `TooManyRequests` (429) — @Gabriel
- Tests de integración para Service, Node, Task, Swarm, System, Image y Container — @Gabriel

### Mejoras internas
- Modelos movidos a `lib/docker_swarm/models/` — @Gabriel
- `Base.all` normalizado para respuestas envueltas (`root_key`) — @Gabriel
- Método `logs` estandarizado a nivel de instancia — @Gabriel
- `Swarm` y `System` heredan de `Base` con atributos dinámicos — @Gabriel
- Jerarquía de errores reestructurada bajo `DockerSwarm::Error` con aliases — @Gabriel

### Correcciones
- Excon ya no envuelve excepciones de negocio en `Excon::Error::Socket` — @Gabriel
- `Volume.all` corregido para la respuesta envuelta de Docker — @Gabriel
- `Gateway_Timeout` renombrado a `GatewayTimeout` — @Gabriel
- Entry point `lib/docker-swarm.rb` agregado para Bundler/Rails — @Gabriel
- Validaciones de `Service` relajadas para flexibilidad en tests — @Gabriel

---

## [0.1.0] - Early 2026
- Release inicial con ORM básico para Services, Networks y Volumes — @Gabriel
