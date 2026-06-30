# docker-swarm

[![Gem Version](https://badge.fury.io/rb/docker-swarm.svg)](https://badge.fury.io/rb/docker-swarm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Propósito

ORM ligero y cliente API para Docker Swarm en Ruby. Expone las primitivas del Docker Engine (Service, Node, Task, Container, Network, Volume, Config, Secret, Swarm, System, Image) como modelos `ActiveModel` con CRUD, validaciones y logs estructurados KV. Excon directo sobre el socket Unix (default) o TCP.

## Setup

```ruby
# Gemfile
gem 'docker-swarm', '~> 0.6'
```

```bash
bundle install
```

Quick start:

```ruby
require 'docker_swarm'

DockerSwarm.configure do |config|
  config.socket_path = "unix:///var/run/docker.sock"  # default
  config.log_level   = Logger::INFO
end

DockerSwarm::System.up                  # => "OK"
DockerSwarm::Service.all                # => [#<Service ...>, ...]
DockerSwarm::Service.find("svc-id")     # => nil si no existe
```

Para el contrato completo de la gema (símbolos públicos, gotchas, integración) ver [`skill/SKILL.md`](skill/SKILL.md).

## Índice de artefactos

Documentación normada (RFC-001) por capa:

| Capa | Artefacto | Estado |
|---|---|---|
| Datos | — | `n/a` (gema sin DB) |
| Glosario | [`docs/glossary/glossary.md`](docs/glossary/glossary.md) | completo (primitivas + arquitectura interna) |
| Comportamiento | [`docs/behavior/behavior.md`](docs/behavior/behavior.md) | backfill on-demand (8 flujos) |
| Configuración | [`docs/config/configuracion.md`](docs/config/configuracion.md) | inventario base (7 opciones, sin env vars) |
| Interfaz | [`docs/interface/interface.md`](docs/interface/interface.md) | API Ruby pública (11 modelos + Base + concerns) |
| Topología | [`docs/topology/topology.md`](docs/topology/topology.md) | 3 deps runtime + grafo de contexto |
| Errores | [`docs/errors/errors.md`](docs/errors/errors.md) | estructura (jerarquía + mapeo HTTP; política §c pendiente enrich) |
| Consumidas | [`docs/consumed/docker-engine-api.md`](docs/consumed/docker-engine-api.md) | estructura (Docker Engine API; §c/§e pendiente enrich) |
| Test | [`docs/test/testing.md`](docs/test/testing.md) | estructura (suite RSpec unit+integration; §e-h pendiente enrich) |
| API (operaciones) | — | `n/a` (gema sin superficie HTTP/CLI/eventos; superficie pública = Interfaz) |
| Eventos | — | `n/a` (la gema no emite eventos) |

`n/a` = no aplica al tipo de repo. "pendiente enrich" = el inventario estructural está completo; los campos semánticos (`arch-enrich`) se llenan incremental.

## Desarrollo

```bash
bundle exec rspec --tag ~type:integration   # unit suite
bundle exec rspec                            # incluye integration (requiere Docker socket)
bundle exec rubocop -a                       # lint
```

Release: `/gem-release` (publica a RubyGems via GitHub Action al tag `v*`).

## Licencia

MIT — ver [LICENSE](LICENSE).
