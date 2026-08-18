# Test — docker-swarm

> meta: artefacto · RFC-013 · generado arch-structure + enriquecido arch-enrich · anclado a `v0.10.0` · cobertura: estructura de la suite (`spec/`, `.github/workflows/main.yml`); §e enriquecida, §f enriquecida, §g `unknown` (sin incidentes registrados), §h enriquecida
> · refresh #39 (cobertura de `update`/`restart`/`stats`, unit + integration; el ancla sigue en `v0.10.0` — el re-anclaje va con la release 0.12.0, #40)

## 1. Resumen

Suite RSpec en dos niveles: **unit** (mockean `DockerSwarm::Api`/`Excon`, sin daemon) e **integration** (`type: :integration`, requieren un Docker daemon real). CI corre solo unit + RuboCop; integration es local/opt-in. Sin herramienta de coverage configurada.

## 2. Cuerpo

### a. Suites, frameworks y niveles

Framework: **RSpec** (`~> 3.0`). `verify_partial_doubles = true` (mocks estrictos).

| subdirectorio | propósito | nivel | helper |
|---|---|---|---|
| `spec/docker/swarm/*_spec.rb` | api, configuration, connection, log_helper, registry_auth | unit | `spec_helper` |
| `spec/docker/swarm/middleware/*_spec.rb` | error_handler, log_stream_demuxer, request_encoder, response_json_parser | unit | `spec_helper` |
| `spec/docker/swarm/models/*_spec.rb` | base, container, image, network, node, service, task + `shared_crud_spec` | unit | `spec_helper` |
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

### e. Gaps de cobertura (narrado)

> Cobertura declarada — qué flujos de negocio están ejercitados y cuáles no. No es el % de líneas (no hay SimpleCov, §d).

**Cubierto (unit, con mocks):**
- Mapeo de errores HTTP → excepción: `error_handler_spec` (subset de status verificado: 200, 404, 429, 500 — no los 14).
- Modelos con métodos propios: `service` (incl. lógica de update/version), `node`, `task`, `container` (start/stop/restart/stats/update), `network`, `base` (accessors dinámicos, `assign_attributes`/`Spec` merge).
- CRUD genérico de `config`, `secret`, `volume`: vía `shared_crud_spec` (`it_behaves_like "a crud resource"`) — no tienen spec dedicado pero **sí** están cubiertos (create/find/destroy). `image` salió del CRUD genérico (su `create` era un pull) → tiene spec propio (abajo).
- `image`: `image_spec` (dedicado) — `Image.pull` (stream NDJSON, extracción de digest del frame `Digest:`, error tipado ante `error`/`errorDetail`, forma polimórfica del body) + `Deletable` y listado.
- Auth de registry privado: `registry_auth_spec` (helper `RegistryAuth`: exclusión mutua `registry_auth`/`registry_auth_from`, enum del `from`, traducción a header/query) + bloque registry-auth en `service_spec` (create/update, no-exposición de la credencial en logs).
- Partición query params propios vs. `?filters=` del listado (`index_query_params`): `base_spec` (default, override, partición mixta), `service_spec` (`status: true` → query param; `ServiceStatus` expuesto y tolerancia a su ausencia), `container_spec` (**regresión**: `status` sigue viajando como filtro; y #35: los tres query params de `ContainerList`, `since` ruteado a filtros, `size` a la URL, `force` ausente), `image_spec` (#35: `%i[all digests]`, `since` a filtros, `digests` a la URL). Integration: `services_spec` verifica contra el daemon que `ServiceStatus` aparece **solo** con `status: true`, y un `context` en modo **`global`** pinnea el caso que justifica la feature — `DesiredTasks` legible donde `Spec.Mode.Replicated` no existe. Ese context es el que vuelve necesario el poll del helper `listed_with_status`: en un global el deseado arranca en 0 y el Engine lo completa después (~1s), así que la condición de corte es `DesiredTasks.positive?`, no `ServiceStatus.present?`.
- Superficie de `Container` que faltaba (#39): `container_spec` cubre `restart` (pega al endpoint real, **no** simula con `ForceUpdate` como `Service`; `t` sólo si le pasan `timeout`), `stats` (**fuerza `stream: false`** — si ese ejemplo se cae, el método deja de volver; y **mergea** en vez de reemplazar, para que un caller no se cuelgue sin querer) y `update` (sin `?version=`; devuelve el cuerpo y no un booleano; `reload`ea; **levanta con payload vacío**, que es lo que hace que `save` sobre un persistido falle fuerte en vez de postear `{}`; descarta `registry_auth` tanto como kwarg como clave String del hash posicional). Integration: `containers_spec` corre los tres contra el daemon — **`stats` bajo `Timeout.timeout(15)`, que es lo único que un unitario no puede cubrir** (mockeando `Api.request` se verifica que mandamos `stream: false`, no que eso evite el cuelgue), `restart` comparando `StartedAt`, y `update` verificando el límite en el objeto local **y** en el Engine.
- Infra de transporte: `api_spec`, `connection_spec`, `configuration_spec`, `log_helper_spec`, los 4 middleware specs.
- `swarm`, `system` (singletons): `swarm_spec`, `system_spec`.

**Cubierto (integration, daemon real):** lifecycle de containers, services, infra (networks/volumes), system (info/version/up/df), security (config/secret create+find+destroy).

**Gaps declarados:**
- `error_handler_spec` ejercita **un subset** de los 14 status; 400/401/403/406/408/409/422/502/503/504 y el fallback genérico no tienen aserción dedicada (gap de contrato §f).
- `Service#restart`, `Loggable#logs` — cobertura unit no confirmada por spec dedicado; verificar.
- Path de error `Communication` (socket caído) y la política de retry idempotente: no confirmado que haya spec dedicado en `connection_spec` (verificar).

### f. Contract-assessment (¿los tests ejercitan los contratos públicos?)

| contrato | RFC | cubierto | nota |
|---|---|---|---|
| Interfaz Ruby pública | RFC-004 | parcial | model specs + `shared_crud` ejercitan `all/find/create/update/destroy/logs`; falta aserción sistemática de toda la superficie |
| Errores públicos | RFC-020 | parcial | `error_handler_spec` cubre el mapeo status→excepción pero **solo 4 de 14 status** → contrato de errores incompletamente verificado |
| Docker Engine API consumida | RFC-018 | sí (integration) | los specs `type: :integration` ejercitan el contrato real contra el daemon; unit lo mockea |

### g. Link a incidente

`unknown` — **por ausencia de fuente, no por verificación de que no existan.** No hay un tracker de incidentes vinculado a este repo ni `refs incidente/PR` en los specs o en el historial localizable; por tanto no se puede afirmar ni que haya ni que no haya tests nacidos de un incidente. No es "cero incidentes verificado". Se completará si/cuando un test de regresión se ate explícitamente al bug que previene.

### h. PII / datos sensibles en fixtures

**Sin PII real ni secretos reales.** Clasificación (no valores):

- Nombres de recursos: generados con `random_name(prefix)` → `SecureRandom.hex(4)` (`integration_helper.rb:26`). Sintéticos.
- `Config`/`Secret` Data en integration: literales de prueba base64 (`Base64.strict_encode64("hello world")`, `"top secret"` — `security_spec.rb`). **No** son credenciales reales; son strings de test.
- Unit specs: payloads inline mockeados, sin datos reales.

No cruza RFC-026 (no hay PII de personas ni secretos productivos en fixtures).

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Los specs de modelo unit mockean `Api`/`Excon` (no tocan socket) | inferred | `spec_helper` apunta a `/tmp/docker.sock` inexistente → necesariamente stubean; patrón confirmado en `skill/SKILL.md` |
| Integration requiere daemon Swarm activo | declared | `integration_helper` usa el socket real (`DOCKER_URL` o default) |

## 4. Cobertura y fronteras

- **Contenido de cada test case** individual queda en el código, no acá.
- **Niveles:** solo unit e integration; no hay system/e2e ni matriz de versiones (`Appraisals`) — Ruby único (3.4.4) en CI.
- **Coverage real (%)** no medible desde el repo (sin tool); §d declara la ausencia, no un número.
