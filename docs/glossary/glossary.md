# Glosario — docker-swarm

> meta: artefacto · RFC-009 · generado dev-enrich · anclado a `v0.9.0` · cobertura: completo inicial (primitivas Docker + arquitectura interna); no se acrecienta sin tocar el flujo/concepto
> · refresh #39 (la superficie que expone la gema para Container; el ancla sigue en `v0.9.0` — el re-anclaje va con la release 0.12.0, #40)

## 1. Resumen

Términos de negocio que la gema `docker-swarm` materializa. Dos grupos: **primitivas Docker** (entidades del Engine API expuestas como modelos Ruby) y **conceptos arquitectónicos internos** (mecanismos que sostienen el ORM). Sólo términos de negocio con binding estable. Definiciones técnicas de columnas/atributos no van acá (sería Data Dictionary; n/a en gema sin DB).

## 2. Términos

## Service

Servicio de Docker Swarm: definición declarativa de un conjunto de tasks que corren en el cluster. La gema lo expone como CRUD completo + `restart` + `logs`. Update atómico vía `Version.Index`.
**Binding:** [`DockerSwarm::Service`](../../lib/docker_swarm/models/service.rb)

## Node

Miembro físico del cluster Swarm (manager o worker). Read-only desde el punto de vista de creación: los nodos se unen al swarm fuera de la gema; la gema sólo permite update (rol/disponibilidad) y destroy.
**Binding:** [`DockerSwarm::Node`](../../lib/docker_swarm/models/node.rb)

## Task

Unidad de ejecución de un Service en un Node específico. Read-only: las tasks se generan automáticamente por el orquestador a partir del Spec del Service. La gema sólo permite listar/inspeccionar/obtener logs.
**Binding:** [`DockerSwarm::Task`](../../lib/docker_swarm/models/task.rb)

## Container

Container Docker standalone (no Swarm). La gema expone create/start/stop/restart/stats/update/destroy/logs. La creación estuvo fuera de scope en F1 —el caso de uso primario de la gema es Swarm— y entró con ADR-025 cláusula 1: operar datos on-host durante una migración necesita un **helper container efímero** con nombre determinista, que es lo que habilita adoptarlo en un reintento en vez de duplicarlo.
**Binding:** [`DockerSwarm::Container`](../../lib/docker_swarm/models/container.rb)

## Image

Imagen Docker (registry o local). La gema cubre listar, pull (`Image.pull`, explícito y síncrono) y destroy. Build local no cubierto (no caso de uso de orquestación). El `create` genérico se retiró: `Image` ya no es Creatable.
**Binding:** [`DockerSwarm::Image`](../../lib/docker_swarm/models/image.rb)

## Network

Red Docker (overlay para Swarm, bridge para Container). CRUD completo. Update soporta conectar/desconectar containers.
**Binding:** [`DockerSwarm::Network`](../../lib/docker_swarm/models/network.rb)

## Volume

Volumen Docker (named volume). CRUD sin update (Docker no soporta update de Volume). La respuesta del index viene envuelta en `{"Volumes": [...]}` — manejado vía `root_key`.
**Binding:** [`DockerSwarm::Volume`](../../lib/docker_swarm/models/volume.rb)

## Config

Configuración inmutable distribuida en el cluster (archivos de configuración, manifests). CRUD sin update — Docker requiere recrear. Sólo Swarm.
**Binding:** [`DockerSwarm::Config`](../../lib/docker_swarm/models/config.rb)

## Secret

Dato sensible distribuido en el cluster (passwords, tokens, certs). Misma semántica que Config pero el `Data` se filtra automáticamente en logs vía `LogHelper`. Sólo Swarm.
**Binding:** [`DockerSwarm::Secret`](../../lib/docker_swarm/models/secret.rb)

## Swarm

Cluster Docker Swarm como entidad singleton. Sólo `show` (info del cluster: ID, Version, Spec, JoinTokens). No CRUD — el cluster se inicializa/disuelve fuera de la gema.
**Binding:** [`DockerSwarm::Swarm`](../../lib/docker_swarm/models/swarm.rb)

## System

Daemon Docker como entidad singleton. Métodos estáticos: `info`, `version`, `up` (ping), `df` (disk usage). Útil para health checks y observabilidad.
**Binding:** [`DockerSwarm::System`](../../lib/docker_swarm/models/system.rb)

---

## Base (ORM base)

Clase base de todos los modelos. Hereda de `ActiveModel::Model`. Provee accessors dinámicos PascalCase, `find`, `all`, `where`, `reload`, `payload_for_docker`. Centraliza el patrón ORM contra Docker Engine API.
**Binding:** [`DockerSwarm::Base`](../../lib/docker_swarm/base.rb)

## Concern

Mixin (`ActiveSupport::Concern`) que agrega capacidad CRUD/auxiliar a un modelo. La gema define cinco concerns ortogonales: cada modelo incluye los que aplican a su semántica Docker.

| Concern | Símbolo | Aplica a |
|---|---|---|
| Creatable | [`DockerSwarm::Concerns::Creatable`](../../lib/docker_swarm/concerns/creatable.rb) | Service, Network, Volume, Config, Secret |
| Updatable | [`DockerSwarm::Concerns::Updatable`](../../lib/docker_swarm/concerns/updatable.rb) | Service, Node, Network |
| Deletable | [`DockerSwarm::Concerns::Deletable`](../../lib/docker_swarm/concerns/deletable.rb) | Service, Node, Container, Network, Volume, Config, Secret, Image |
| Loggable | [`DockerSwarm::Concerns::Loggable`](../../lib/docker_swarm/concerns/loggable.rb) | Service, Task, Container |
| Inspectable | [`DockerSwarm::Concerns::Inspectable`](../../lib/docker_swarm/concerns/inspectable.rb) | Todos (vía Base) |

## Middleware

Capa Excon en el stack del cliente HTTP. Tres middlewares custom: serialización de body, parsing de respuesta con indifferent access, mapeo de status a excepción tipada.

| Middleware | Símbolo | Rol |
|---|---|---|
| RequestEncoder | [`DockerSwarm::Middleware::RequestEncoder`](../../lib/docker_swarm/middleware/request_encoder.rb) | Serializa body (JSON / x-www-form / multipart) según Content-Type |
| ResponseJSONParser | [`DockerSwarm::Middleware::ResponseJSONParser`](../../lib/docker_swarm/middleware/response_json_parser.rb) | Parsea JSON y aplica `with_indifferent_access` |
| ErrorHandler | [`DockerSwarm::Middleware::ErrorHandler`](../../lib/docker_swarm/middleware/error_handler.rb) | Mapea 4xx/5xx → `DockerSwarm::Error::*` + log `business_error` |

## Connection

Wrapper sobre el cliente Excon. Memoiza la conexión, aplica timeouts/retries de configuración, clasifica errores idempotentes vs no-idempotentes (post-fix correctness), y emite logs KV.
**Binding:** [`DockerSwarm::Connection`](../../lib/docker_swarm/connection.rb)

## Dynamic Accessor

Mecanismo por el cual los modelos exponen atributos no declarados. Docker Engine evoluciona y agrega campos: la gema usa `method_missing` + cache en `defined_attributes` (Set) para responder a cualquier campo PascalCase de la respuesta sin requerir update del código.
**Binding:** [`DockerSwarm::Base#method_missing`](../../lib/docker_swarm/base.rb), [`DockerSwarm::Base.defined_attributes`](../../lib/docker_swarm/base.rb)

## Spec deep_merge

Estrategia de actualización parcial del campo `Spec` de un modelo. En vez de reemplazar Spec completo, `assign_attributes` hace `deep_merge` cuando la key es `Spec` y ambos valores son Hash. Razón: updates parciales no pierden campos anidados no tocados.
**Binding:** [`DockerSwarm::Base#assign_attributes`](../../lib/docker_swarm/base.rb)

## Version.Index

Mecanismo de control de concurrencia optimista de Docker para updates atómicos. Cada Service/Node tiene `Version.Index` que incrementa en cada cambio. Update requiere enviar el index actual como query param; si no coincide, Docker rechaza (500). La gema lo extrae automáticamente en `Updatable#update`.
**Binding:** [`DockerSwarm::Concerns::Updatable#update`](../../lib/docker_swarm/concerns/updatable.rb)

## LogHelper

Módulo de formateo de logs en KV (`key=value`) con masking automático de claves sensibles. La regex (`password|pass|passwd|secret|token|api_key|auth|\bdata\b`) reemplaza valores por `[FILTERED]`. `\bdata\b` evita falsos positivos en `metadata`/`database`.
**Binding:** [`DockerSwarm::LogHelper`](../../lib/docker_swarm/log_helper.rb)

## payload_for_docker

Transformación interna que prepara un modelo para enviarlo al API: descarta atributos internos (`ID`/`Version`/`CreatedAt`/`UpdatedAt`), extrae el contenido de `Spec` al root y mergea otros campos top-level. Resultado: el payload que Docker espera para `create`/`update`.
**Binding:** [`DockerSwarm::Base#payload_for_docker`](../../lib/docker_swarm/base.rb)

## 3. Inferencias

| Término | Inferencia | Confidence | Verificar |
|---|---|---|---|
| Spec deep_merge | "razón: updates parciales no pierden campos" | declared | confirmado en CLAUDE.md decisión arquitectura |
| Dynamic Accessor | "Docker evoluciona y agrega campos" | declared | confirmado en CLAUDE.md decisión arquitectura |

## 4. Cobertura y fronteras

- **Cobertura:** Completa para primitivas Docker (11) y conceptos arquitectónicos internos (9). Esta es una corrida inicial (sembrado autorizado, RFC-009).
- **Frontera con Data Dictionary (RFC-002 §2.c r4):** la gema **no tiene capa de datos** (no DB, no `docs/data/`). Definiciones de columnas/atributos = `n/a`. Atributos PascalCase de Docker (`Spec`, `TaskTemplate`, etc.) son contrato de la API Docker, no del dominio de esta gema — no entran al glosario.
- **Frontera con comportamiento:** flujos (create+reload, retry, error-mapping) viven en [`docs/behavior/behavior.md`](../behavior/behavior.md), no acá.
- **Fuera de alcance:**
  - Términos técnicos puros sin significado de negocio (ej: `instance_values`, `attr_accessor`) — son detalles de implementación, no contrato.
  - Glossary del Docker Engine API (cómo funciona internamente Swarm, raft, gossip) — vive en docs de Docker, no se duplica acá.
- **Inferencia resuelta (2026-08-03):** §3 registraba como `inferred` la pregunta de si *"creación intencionalmente fuera de scope F1"* era una decisión de alcance o un gap a cubrir. Quedó resuelta: **era una decisión de alcance** (Swarm-first), y ADR-025 cláusula 1 **amplió el alcance** al aparecer un caso de uso real (el helper container efímero de la migración del ACS). La fila salió de §3 porque ya no es una inferencia pendiente.
- **Cadencia:** incremental por PR a partir de acá; ausencia ≠ inexistencia (RFC-009).
