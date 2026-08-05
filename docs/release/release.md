# Release — docker-swarm

> meta: artefacto · RFC-014 · generado arch-structure + enriquecido arch-enrich · anclado a `v0.10.0` · cobertura: §a estructura completa (versión · changelog · build-trigger · patrón); §b enrich completa (deploy · rollback · ambientes · dueño)

## 1. Resumen

Gema Ruby publicada en RubyGems. Release por **tag `v*`**: el push del tag dispara el workflow `Publish to RubyGems` que hace `gem build` + `gem push`. Sin deploy de infraestructura (gema, no servicio): no hay `Dockerfile`, ni branches `production`/`staging`, ni ambientes.

## 2. Cuerpo

### §a Estructura (verificable del código)

| campo | valor | fuente |
|---|---|---|
| versión actual | `0.10.0` | `lib/docker_swarm/version.rb` (`DockerSwarm::VERSION`) |
| esquema de versión | SemVer (`MAJOR.MINOR.PATCH`) | `CHANGELOG.md` (breaking/mejoras/correcciones por bump) |
| artefacto liberado | gema `docker-swarm` a RubyGems | `docker-swarm.gemspec` (`spec.name`), `.github/workflows/release.yml` |
| changelog | `CHANGELOG.md`, formato Keep a Changelog, entradas fechadas por versión | `CHANGELOG.md` |
| licencia | MIT | `docker-swarm.gemspec` (`spec.license`) |
| build-trigger | push de tag `v*` | `.github/workflows/release.yml` (`on.push.tags: ['v*']`) |
| **patrón de trigger (RFC-014)** | **patrón 1** — publish per-repo-visible en workflow (tag → RubyGems) | `.github/workflows/release.yml` |
| runner de release | `ubuntu-latest`, Ruby `3.4.4` | `.github/workflows/release.yml` |
| pasos de publish | `gem build *.gemspec` + `gem push *.gem` | `.github/workflows/release.yml` |
| credencial de publish | `secrets.RUBYGEMS_API_KEY` (env `RUBYGEMS_API_KEY`) | `.github/workflows/release.yml` |
| MFA de publish | requerida (`rubygems_mfa_required = "true"`) | `docker-swarm.gemspec` (`spec.metadata`) |
| Ruby mínimo del release | `>= 3.2.0` | `docker-swarm.gemspec` (`required_ruby_version`) |
| contenido empaquetado | `lib`, `exe`, `skill`, `docs` + `README.md`, `CHANGELOG.md`, `LICENSE` | `docker-swarm.gemspec` (`spec.files`). Empaquetar `skill/` + `docs/` es **intencional**: la gema shippea su skill version-locked (RFC-008) y los artefactos de arquitectura para consumidores/agentes |
| CI (no gatea el release) | workflow `Ruby` (`main.yml`) corre en push a `main` / PR: `rspec` (sin `type:integration`) + `rubocop`. **Independiente** de `release.yml` — el tag `v*` publica sin exigir que el CI haya pasado | `.github/workflows/main.yml` |
| dependencias runtime | `activesupport >= 6.0`, `activemodel >= 6.0`, `excon >= 0.80` | `docker-swarm.gemspec` |

### §b Deploy · rollback · ambientes · dueño (enrich)

| dimensión | valor | nota |
|---|---|---|
| deploy | Publicación a RubyGems por `gem push` al pushear el tag `v*`. Los consumidores la reciben vía Bundler (`gem 'docker-swarm'`) tras la propagación del índice de RubyGems (~minutos) | "Deploy" para una gema = disponibilidad en RubyGems; no hay infraestructura que desplegar |
| rollback | **Bump correctivo (preferido):** publicar un patch nuevo (`X.Y.Z+1`) con el fix. RubyGems **prohíbe** re-pushear el mismo número de versión (restricción técnica). `gem yank -v X.Y.Z` — RubyGems lo permite en cualquier momento (no hay restricción técnica), pero es **política del equipo** reservarlo a casos graves (secreto filtrado, gema rota/ininstalable) | Distinguir: el re-push prohibido es técnico de RubyGems; el yank restringido es decisión del equipo (un yank rompe a quien fijó esa versión → se prefiere avanzar) |
| ambientes | No aplica: artefacto único publicado en RubyGems, sin staging/producción. El único "ambiente" es la versión instalada por cada consumidor | La matriz de compatibilidad la fija `required_ruby_version` (`>= 3.2.0`), no un ambiente de deploy |
| dueño del release | Gabriel (mantenedor) — taggea `v*` y publica; @Pablo contribuye fixes | Derivado del historial de `CHANGELOG.md` y confirmado por el equipo |

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Patrón de trigger = 1 (publish per-repo-visible por tag), no patrón 3 (branch `production`/`staging`) | declared | `release.yml` sólo escucha `tags: v*`; no existen branches `production`/`staging` (`git branch -a`) |
| Esquema de versión = SemVer | inferred | derivado del uso en `CHANGELOG.md` (0.7.0 marcó breaking changes); no hay política SemVer declarada explícita en el repo |
| No hay deploy de infra | declared | ausencia de `Dockerfile`, `docker-compose.yml`, `helm/`, branches de ambiente — es gema, no servicio |
| El gem se buildea bajo Ruby `3.4.4` aunque declara floor `>= 3.2.0` | declared | runner fijo en `release.yml` (`3.4.4`) vs `required_ruby_version` del gemspec (`>= 3.2.0`); no es defecto — el build no acopla el floor de compatibilidad |

## 4. Cobertura y fronteras

- **Estructura (§a) y enrich (§b) completas** al ancla `cccfe63`; significado de §b aportado por el mantenedor.
- **Proceso operativo del release** (quién taggea, checklist, bump de versión) lo ejecuta la skill `gem-release`; este artefacto documenta el contrato, no el paso-a-paso de la skill.
- **Trade-off conocido:** el release (`release.yml`, tag `v*`) **no exige** que el CI (`main.yml`) haya pasado — un tag publica aunque los tests fallen. Hoy el gate es de facto (el dev corre la suite antes de taggear), no forzado por el pipeline. Endurecerlo (exigir CI verde antes de publicar) es una mejora de proceso pendiente, no documentada como decisión formal.
- **Fuera de alcance:** la config runtime de la gema vive en `docs/config/configuracion.md`; la suite y su gate CI en `docs/test/testing.md` (este artefacto sólo referencia el gate pre-release, no lo redefine).
