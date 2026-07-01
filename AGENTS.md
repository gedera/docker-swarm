# DockerSwarm — Project Intelligence

## Qué es DockerSwarm

Gema Ruby que provee un ORM compatible con ActiveModel para Docker Engine API. Permite gestionar servicios, nodos, tasks, containers, networks, volumes, configs, secrets e imágenes de un cluster Docker Swarm como objetos Ruby con CRUD, validaciones y logging estructurado.

## Documentación

- **Para humanos**: `docs/` + `README.md`. Ver README para índice.
- **Para agentes AI**: `skill/SKILL.md` + `skill/references/`. Es la skill empaquetada que otros proyectos consumen via `skill-manager sync`.
- **Nunca referenciar `skill/` desde `docs/` o `README.md`** — son audiencias distintas.

## Mapa de conocimiento

Wayfinding in-repo de los artefactos de arquitectura (RFC-008 r2). Espejo del "Índice de artefactos" del README.

| Capa | RFC | Artefacto | Estado |
|---|---|---|---|
| Datos | RFC-002 | — | `n/a` (gema sin DB) |
| Glosario | RFC-009 | `docs/glossary/glossary.md` | completo |
| Comportamiento | RFC-007 | `docs/behavior/behavior.md` | backfill on-demand (8 flujos) |
| Configuración | RFC-012 | `docs/config/configuracion.md` | inventario base (7 opciones, sin env vars) |
| Interfaz | RFC-004 | `docs/interface/interface.md` | API Ruby pública (11 modelos + Base + concerns) |
| Topología | RFC-006 | `docs/topology/topology.md` | 3 deps runtime + grafo de contexto |
| Errores | RFC-020 | `docs/errors/errors.md` | jerarquía + mapeo HTTP + política §c |
| Consumidas | RFC-018 | `docs/consumed/docker-engine-api.md` | Docker Engine API + retry/degradación §c/§e |
| Test | RFC-013 | `docs/test/testing.md` | RSpec unit+integration + gaps/contract/PII §e-h (§g sin incidentes) |
| Release | RFC-014 | `docs/release/release.md` | §a estructura (tag `v*`→RubyGems, patrón 1); deploy/rollback/ambientes/dueño pendientes (enrich) |
| API (operaciones) | RFC-003 | — | `n/a` (gema sin superficie HTTP/CLI/eventos; superficie pública = Interfaz) |
| Eventos | RFC-005 | — | `n/a` (la gema no emite eventos) |
| Seguridad | RFC-017 | — | `n/a` (sin authn/authz propios; la frontera auth-hacia-Docker vive en `docs/consumed/docker-engine-api.md` §a) |
| Multi-tenancy | RFC-023 | — | `n/a` (gema stateless sin DB ni scope de tenant) |
| Data-lifecycle | RFC-026 | — | `n/a` (sin persistencia/PII/retención; fixtures sintéticas) |

## Convenciones del framework

- El repo **consume** skills del framework, declaradas en `skills.yml`.
- Las skills en `.agents/skills/` traen conocimiento de las dependencias del repo.
- Leer la skill de una dependencia ANTES de responder sobre ella.

## Knowledge Base

- Las skills en `.agents/skills/` incluyen conocimiento de dependencias.
- Leer la skill de una dependencia ANTES de responder sobre ella.
- Rebuild: `wispro-agent sync`

### Entorno

- Versión de Ruby: leer `.ruby-version`
- Versión de Rails y gemas: leer `Gemfile.lock`
- Gestor de Ruby: chruby (no usar rvm ni rbenv)
- Package manager: Bundler

### RuboCop

- Usamos rubocop-rails-omakase como base.
- Correr `bundle exec rubocop -a` antes de commitear.
- No deshabilitar cops sin justificación en el PR.

### YARD

- Documentación incremental: si tocás un método, documentalo con YARD.
- Consultar la skill `yard` para tags y tipos correctos.
- Verificar cobertura: `bundle exec yard stats --list-undoc`

### Testing

- Framework: RSpec
- Correr: `bundle exec rspec`
- Todo código nuevo debe tener tests.

### Releases o Nuevas versiones

- Usar `/gem-release` para publicar nuevas versiones.
- El GitHub Action publica a RubyGems automáticamente al pushear un tag `v*`.

## Decisiones de Arquitectura

- **PascalCase fiel**: Los atributos mantienen el naming de Docker (`Spec`, `TaskTemplate`, `ContainerSpec`). No se transforman a snake_case para evitar confusión con la documentación de Docker.
- **Excon sobre Faraday**: Excon soporta Unix sockets nativamente y tiene un middleware stack más liviano. No necesitamos los adapters de Faraday.
- **Dynamic Accessors**: `method_missing` + `respond_to_missing?` en vez de generación de código estático, porque Docker puede agregar campos nuevos en cualquier versión del API.
- **Deep Indifferent Access recursivo**: Toda respuesta JSON se convierte a `HashWithIndifferentAccess` incluyendo arrays anidados.
- **Spec deep_merge**: `assign_attributes` mergea el campo `Spec` en vez de reemplazarlo, para no perder campos anidados en updates parciales.
