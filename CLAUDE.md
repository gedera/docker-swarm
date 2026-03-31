# Docker Swarm Gem - Development Guide

## Build & Test Commands
- **Install dependencies**: `bundle install`
- **Run tests**: `bundle exec rspec`
- **Run linter**: `bundle exec rubocop`
- **Auto-fix lint issues**: `bundle exec rubocop -A`
- **Build gem**: `gem build docker-swarm.gemspec`

## Architectural Standards
- **Naming**: Use `DockerSwarm` as the root namespace.
- **Attributes**: Docker returns attributes in `PascalCase` (e.g. `Spec`, `Version`). Maintain this in the ORM for direct mapping.
- **ORM Pattern**: Inherit from `DockerSwarm::Base` for resources. Include concerns `Creatable`, `Updatable`, `Deletable` as needed.
- **API Pattern**: Define endpoints in `DockerSwarm::Api::ENDPOINTS` and use `Api.request`.
- **Communication**: Use the internal `Excon` stack with middlewares (request encoder, response parser, error handler).

## Error Handling
- Use internal exceptions defined in `DockerSwarm::Errors`.
- Avoid leaking raw `Excon` or `JSON` errors; wrap them in `DockerSwarm::Error`.

## Code Style
- Follow RuboCop defaults defined in the project.
- Use YARD for documenting methods and params.
- Prefer `&.` for safe navigation.
