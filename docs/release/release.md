# Release — docker-swarm

> meta: artefacto · RFC-014 · generado arch-structure · anclado a `cccfe63` · cobertura: §a estructura completa (versión · changelog · build-trigger · patrón); deploy · rollback · ambientes · dueño sembrados `—` (→ arch-enrich)

## 1. Resumen

Gema Ruby publicada en RubyGems. Release por **tag `v*`**: el push del tag dispara el workflow `Publish to RubyGems` que hace `gem build` + `gem push`. Sin deploy de infraestructura (gema, no servicio): no hay `Dockerfile`, ni branches `production`/`staging`, ni ambientes.

## 2. Cuerpo

### §a Estructura (verificable del código)

| campo | valor | fuente |
|---|---|---|
| versión actual | `0.7.2` | `lib/docker_swarm/version.rb` (`DockerSwarm::VERSION`) |
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
| contenido empaquetado | `lib`, `exe`, `skill`, `docs` + `README.md`, `CHANGELOG.md`, `LICENSE` | `docker-swarm.gemspec` (`spec.files`) |
| CI (no gatea el release) | workflow `Ruby` (`main.yml`) corre en push a `main` / PR: `rspec` (sin `type:integration`) + `rubocop`. **Independiente** de `release.yml` — el tag `v*` publica sin exigir que el CI haya pasado | `.github/workflows/main.yml` |
| dependencias runtime | `activesupport >= 6.0`, `activemodel >= 6.0`, `excon >= 0.80` | `docker-swarm.gemspec` |

### §b Deploy · rollback · ambientes · dueño (enrich — sembrado `—`)

| dimensión | valor | nota |
|---|---|---|
| deploy | `—` | → arch-enrich |
| rollback | `—` | → arch-enrich (yank / bump correctivo) |
| ambientes | `—` | → arch-enrich |
| dueño del release | `—` | → arch-enrich |

## 3. Inferencias

| afirmación | confidence | a verificar |
|---|---|---|
| Patrón de trigger = 1 (publish per-repo-visible por tag), no patrón 3 (branch `production`/`staging`) | declared | `release.yml` sólo escucha `tags: v*`; no existen branches `production`/`staging` (`git branch -a`) |
| Esquema de versión = SemVer | inferred | derivado del uso en `CHANGELOG.md` (0.7.0 marcó breaking changes); no hay política SemVer declarada explícita en el repo |
| No hay deploy de infra | declared | ausencia de `Dockerfile`, `docker-compose.yml`, `helm/`, branches de ambiente — es gema, no servicio |
| El gem se buildea bajo Ruby `3.4.4` aunque declara floor `>= 3.2.0` | declared | runner fijo en `release.yml` (`3.4.4`) vs `required_ruby_version` del gemspec (`>= 3.2.0`); no es defecto — el build no acopla el floor de compatibilidad |

## 4. Cobertura y fronteras

- **Estructura (§a) completa** al ancla `cccfe63`.
- **Enrich (§b) pendiente:** deploy · rollback · ambientes · dueño → `arch-enrich` (para una gema, "deploy" = disponibilidad en RubyGems; "rollback" = `gem yank` o bump correctivo — a documentar por el humano, no inventado).
- **Proceso operativo del release** (quién taggea, checklist, changelog manual vs automatizado) lo ejecuta la skill `gem-release` — no es parte de este artefacto estructural; su documentación operativa va a §b enrich.
- **Fuera de alcance:** la config runtime de la gema vive en `docs/config/configuracion.md`; la suite y su gate CI en `docs/test/testing.md` (este artefacto sólo referencia el gate pre-release, no lo redefine).
