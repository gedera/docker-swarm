# Configuración — docker-swarm

> meta: artefacto · RFC-012 · generado arch-structure · anclado a `e8c7594` · cobertura: configuración runtime de la gema (clase `DockerSwarm::Configuration`, seteada vía `DockerSwarm.configure`)

## 1. Resumen

Configuración runtime de la gema. 7 opciones, todas programáticas vía `DockerSwarm.configure { |c| ... }` sobre `DockerSwarm::Configuration` (`lib/docker_swarm/configuration.rb`). **Cero env vars** (verificado: sin `ENV[`/`ENV.fetch` en `lib/`). Todas con default; ninguna requerida ni secreta.

## 2. Cuerpo

### a. Hecho verificable (conteos)

| métrica | valor |
|---|---|
| total opciones | 7 |
| requeridas | 0 |
| con default | 7 |
| derivadas | 0 |
| secretas | 0 |

### b. Inventario base

| nombre | tipo | requerida | default | origen | consumidor (file:line) | secret? |
|---|---|---|---|---|---|---|
| `socket_path` | String | no | `"unix:///var/run/docker.sock"` | code-default | `connection.rb:116-119` (vía `docker_swarm.rb:28`) | no |
| `logger` | Logger | no | `Logger.new($stdout)` | code-default | `docker_swarm.rb:19-20,28` · `connection.rb:70-85` | no |
| `log_level` | Integer (Logger level) | no | `Logger::INFO` | code-default | `docker_swarm.rb:20` | no |
| `read_timeout` | Float | no | `60.0` | code-default | `connection.rb:29` | no |
| `write_timeout` | Float | no | `60.0` | code-default | `connection.rb:30` | no |
| `connect_timeout` | Float | no | `10.0` | code-default | `connection.rb:31` | no |
| `max_retries` | Integer | no | `3` | code-default | `connection.rb:32` | no |

> Definición/categoría/failure-mode/side-effect/business-reason: `—` (sembrado, lo llena `arch-enrich` §f).

### c. Meta-templates

Plantilla `<x>_timeout` (≥3 instancias):

- Instancias: `read_timeout`, `write_timeout`, `connect_timeout`.
- Tipo común: `Float`. Setter coacciona valor con `&.to_f` (`configuration.rb:20-30`).
- Delta por instancia: default `read`/`write` = `60.0`; `connect` = `10.0`.
- Consumo: pasadas a Excon como opciones homónimas (`connection.rb:29-31`).

### d. Derivaciones simples

`—` n/a. No hay constantes derivadas de otras opciones.

### e. Scheduling

`—` n/a. Gema cliente sin scheduler (`sidekiq.yml`/`queue.yml`/`recurring.yml` ausentes).

### i. Inyecciones al host

`—` n/a. Sin Railtie/Engine (`lib/**/railtie.rb`/`engine.rb` y `lib/generators/` ausentes). Único efecto al configurar: `DockerSwarm.configure` setea `logger.level = log_level` (`docker_swarm.rb:19-20`) — efecto sobre el logger inyectado por el consumidor, no sobre el host.

### j. Inyección a gemas configuradas

`—` n/a. No configura otras gemas.

## 3. Inferencias

| inferencia | confidence | a verificar |
|---|---|---|
| Sin env vars: config 100% programática vía `DockerSwarm.configure` | declared | `grep -rn "ENV" lib/` → 0 hits (verificado) |
| `log_level` es constante `Logger` (Integer 0-5); default `Logger::INFO` (=1) | declared | `configuration.rb:13` |
| `max_retries` se aplica **solo** a requests idempotentes; en no-idempotentes Excon recibe `retries: 0` | inferred | `connection.rb:32` (`idempotent ? max_retries : 0`) |
| `socket_path` soporta unix socket (`unix://`) y TCP; el transporte se ramifica por prefijo | inferred | `connection.rb:116-119` (`start_with?("unix://")`) |

## 4. Cobertura y fronteras

- **Frontera con el consumidor:** la gema no lee env. Un servicio que la usa puede mapear sus propias env vars a estos setters en su initializer — eso pertenece al `docs/config/` del consumidor, no a este artefacto.
- **Enriquecimiento pendiente:** columnas semánticas (`categoría`, `failure-mode`, `side-effect`, `scope-override`, `business-reason`) sembradas `—` → las llena `arch-enrich` (§f Enriquecimiento semántico).
- **n/a en esta capa:** §d derivaciones, §e scheduling, §i inyecciones al host, §j inyección a gemas — la gema es cliente puro sin Railtie/scheduler/derivaciones.
- **Linter de secrets:** sin hallazgos (ningún default con literal sensible; ningún nombre matchea `*_KEY|*_SECRET|*_PASS|*_TOKEN`).
