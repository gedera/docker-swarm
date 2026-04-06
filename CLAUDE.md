# DockerSwarm — Project Intelligence

## Qué es DockerSwarm

Gema Ruby que provee un ORM compatible con ActiveModel para Docker Engine API. Permite gestionar servicios, nodos, tasks, containers, networks, volumes, configs, secrets e imágenes de un cluster Docker Swarm como objetos Ruby con CRUD, validaciones y logging estructurado.

## Documentación

- **Para humanos**: `docs/` (5 archivos) + `README.md`. Ver README para índice.
- **Para agentes AI**: `skill/SKILL.md` + `skill/references/`. Es la skill empaquetada que otros proyectos consumen via `skill-manager sync`.
- **Nunca referenciar `skill/` desde `docs/` o `README.md`** — son audiencias distintas.

## Knowledge Base
- Las skills en `.agents/skills/` incluyen conocimiento de dependencias.
- Leer la skill de una dependencia ANTES de responder sobre ella.
- Rebuild: `ruby .agents/skills/skill-manager/scripts/sync.rb`

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
