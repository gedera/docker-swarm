# Changelog

All notable changes to this project will be documented in this file.

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
