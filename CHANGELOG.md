# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Nuevas funcionalidades
- `Container` pasa a incluir `Concerns::Creatable`: la gema ya puede **crear** containers, no solo operar los existentes. El nombre viaja por **query string** (`POST /containers/create?name=`), que es donde el Engine lo espera — en el body lo descarta en silencio y responde `201`, dejando el container con nombre aleatorio. `Concerns::Creatable` gana `create_query_params` (default `[]`, override por modelo; `Container` declara `%w[name]`) y `query_params_for_docker`; `save` los manda en la URL y los excluye del payload. Implementa ADR-025 cláusula 1 — @gedera

### Breaking changes
- **`logs` devuelve texto demultiplexado.** Sin TTY el Engine enmarca cada fragmento con 8 bytes de cabecera (tipo de stream · relleno · tamaño big-endian); el nuevo `Middleware::LogStreamDemuxer` los saca, así que `Loggable#logs` entrega texto limpio en `Container`, `Service` y `Task`. **Cambia el valor de retorno** para cualquier consumidor que hoy reciba el body crudo. Un stream sin framing (TTY) pasa intacto. Implementa ADR-025 cláusula 3 — @gedera
  - El dispatch **no** se decide solo por `Content-Type`: `application/vnd.docker.multiplexed-stream` existe desde la **API v1.42**, y antes un stream multiplexado viajaba igual como `application/vnd.docker.raw-stream`. Como la gema no fija `?version=`, un Engine que tope en v1.41 devuelve `raw-stream` **con** framing. Ante `raw-stream` el middleware valida la **forma del frame** y solo demultiplexa si la cadena cierra de punta a punta; ante cualquier inconsistencia devuelve el body intacto. Esto se desvía del rationale de `ADR-025:106-107` (no de su Decisión) — corrección pendiente de asentar.

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
