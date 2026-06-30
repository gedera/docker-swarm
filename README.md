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
| Glosario | [`docs/glossary/glossary.md`](docs/glossary/glossary.md) | F1 completo |
| Comportamiento | [`docs/behavior/behavior.md`](docs/behavior/behavior.md) | F1 backfill on-demand (8 flujos) |
| Configuración | [`docs/config/configuracion.md`](docs/config/configuracion.md) | F6 inventario base (7 opciones, sin env vars) |
| API (operaciones) | — | F2 pendiente; contrato resumido inline en `skill/SKILL.md` |
| Interfaz | — | F2 pendiente; contrato resumido inline en `skill/SKILL.md` |
| Topología | — | F2 pendiente |
| Errores | — | F2 pendiente; `lib/docker_swarm/errors.rb` |
| Consumidas | — | F2 pendiente (Docker Engine API) |
| Test | — | F2 pendiente |
| Eventos | — | `n/a` (la gema no emite eventos) |

`n/a` = no aplica al tipo de repo. F2 pendiente = capa declarada en la RFC pero todavía no implementada en `arch-structure`; el contenido relevante vive transitoriamente en `skill/SKILL.md` (RFC-008 §2 coexistencia transitoria).

## Desarrollo

```bash
bundle exec rspec --tag ~type:integration   # unit suite
bundle exec rspec                            # incluye integration (requiere Docker socket)
bundle exec rubocop -a                       # lint
```

Release: `/gem-release` (publica a RubyGems via GitHub Action al tag `v*`).

## Licencia

MIT — ver [LICENSE](LICENSE).
