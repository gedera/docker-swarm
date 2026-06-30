# Test — docker-swarm

> meta: artefacto · RFC-013 · generado arch-structure · anclado a `15bcd21` · cobertura: estructura de la suite (`spec/`, `.github/workflows/main.yml`); §e-§h (gaps/contract-assessment/incidente/PII) sembradas `—` para arch-enrich

## 1. Resumen

Suite RSpec en dos niveles: **unit** (mockean `DockerSwarm::Api`/`Excon`, sin daemon) e **integration** (`type: :integration`, requieren un Docker daemon real). CI corre solo unit + RuboCop; integration es local/opt-in. Sin herramienta de coverage configurada.

## 2. Cuerpo

### a. Suites, frameworks y niveles

Framework: **RSpec** (`~> 3.0`). `verify_partial_doubles = true` (mocks estrictos).

| subdirectorio | propósito | nivel | helper |
|---|---|---|---|
| `spec/docker/swarm/*_spec.rb` | api, configuration, connection, log_helper | unit | `spec_helper` |
| `spec/docker/swarm/middleware/*_spec.rb` | error_handler, request_encoder, response_json_parser | unit | `spec_helper` |
| `spec/docker/swarm/models/*_spec.rb` | base, container, network, node, service, task + `shared_crud_spec` | unit | `spec_helper` |
| `spec/integration/*_spec.rb` | containers, infra, security, services, system | integration | `integration_helper` |

Tag de nivel: las integration declaran `RSpec.describe "...", type: :integration` (`spec/integration/*_spec.rb:5`). Las unit no llevan tag → se filtran con `~type:integration`.

`shared_crud_spec.rb` = shared examples de CRUD reusados por los specs de modelo.

### b. Comando de corrida

| contexto | comando | qué corre |
|---|---|---|
| unit (local) | `bundle exec rspec --tag ~type:integration` | todo menos integration |
| integration (local) | `bundle exec rspec` | incluye integration (requiere Docker socket; override `DOCKER_URL`) |
| lint | `bundle exec rubocop` | rubocop-rails-omakase |
| CI (`.github/workflows/main.yml`) | `bundle exec rspec --tag ~type:integration` + `bundle exec rubocop` | unit + lint, Ruby 3.4.4 |

CI **no** corre integration (no hay daemon en el runner). Se dispara en push a `main` y en `pull_request`.

### c. Fixtures / Factories

- **Sin fixtures YAML ni FactoryBot.** Los datos de prueba se construyen inline en cada spec.
- **Unit:** mockean `DockerSwarm::Api.request` (o `Excon`) con `and_return`/`and_raise` (stubs de respuesta Docker). `spec_helper` configura `socket_path = "unix:///tmp/docker.sock"` y logger a `/dev/null`.
- **Integration:** crean recursos reales contra el daemon; helper `random_name(prefix)` (`integration_helper.rb:26`) genera nombres únicos con `SecureRandom.hex(4)` para evitar colisiones.

### d. Configuración de coverage

Ninguna. No hay `SimpleCov`/`.simplecov` ni umbral declarado en el repo (verificado: sin `SimpleCov` en `spec/` ni en `Gemfile.lock`).

### e–h. Enriquecimiento (gaps · contract-assessment · incidente · PII)

| dimensión | estado |
|---|---|
| §e gaps de cobertura | — |
| §f contract-assessment (cubren RFC-004/018/020) | — |
| §g link a incidente | — |
| §h PII en fixtures | — |

> Sembrado `—` (RFC-013, mitad enrich). Lo completa `arch-enrich`.

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Los specs de modelo unit mockean `Api`/`Excon` (no tocan socket) | inferred | `spec_helper` apunta a `/tmp/docker.sock` inexistente → necesariamente stubean; patrón confirmado en `skill/SKILL.md` |
| Integration requiere daemon Swarm activo | declared | `integration_helper` usa el socket real (`DOCKER_URL` o default) |

## 4. Cobertura y fronteras

- **Contenido de cada test case** individual queda en el código, no acá.
- **Niveles:** solo unit e integration; no hay system/e2e ni matriz de versiones (`Appraisals`) — Ruby único (3.4.4) en CI.
- **Coverage real (%)** no medible desde el repo (sin tool); §d declara la ausencia, no un número.
