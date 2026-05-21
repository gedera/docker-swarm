# Inventario de Configuración — docker-swarm

> meta: artefacto · generado manual · anclado a `b3549e7` · cobertura: archivos de configuración versionados del repo (excluye `lib/`, `spec/`, `skill/`, `docs/`)

## 1. Resumen

Lista de archivos de configuración del repo, qué controlan, quién los consume y dónde tocar para cambiar comportamiento. Agrupados por dominio: **gema**, **Ruby/lint**, **CI/CD**, **dependencias automatizadas**, **agentes/skills**, **entorno local**.

## 2. Gema

### `docker-swarm.gemspec`

Especificación de la gema (nombre, versión, autoría, deps runtime, ficheros incluidos, metadatos RubyGems). Versión leída desde `lib/docker_swarm/version.rb`.

- Ruby mínimo: `>= 3.2.0`
- Runtime deps: `activesupport >= 6.0`, `activemodel >= 6.0`, `excon >= 0.80`
- Dev deps: `rake ~> 13.0`, `rspec ~> 3.0`
- Files glob: `{lib,exe,skill,docs}/**/*` + `README.md`, `CHANGELOG.md`, `LICENSE`
- MFA RubyGems: requerido (`rubygems_mfa_required = true`)
- Cambio típico: bumpear versión → editar `lib/docker_swarm/version.rb` (no acá).

### `Gemfile`

Sólo declara `gemspec` + grupos `:development, :test` y `:test`. Runtime deps viven en el gemspec.

- `:development, :test`: `rspec`, `pry`, `rubocop-rails-omakase`
- `:test`: `activemodel`, `activesupport`, `excon` (re-declaradas para resolver en test sin runtime gemspec)

### `Gemfile.lock`

Lock generado por Bundler. Versionado. No editar a mano.

## 3. Ruby / Lint

### `.rubocop.yml`

Base: `rubocop-rails-omakase`.

- `TargetRubyVersion: 3.2`
- Exclude: `bin/**/*`, `vendor/**/*`, `spec/fixtures/**/*`, `Gemfile`, `Gemfile.lock`, `docker-swarm.gemspec`
- `Style/Documentation`: deshabilitado (ruido masivo; habilitar cuando YARD esté completo)
- `Naming/MethodName`: excluido en `lib/docker_swarm/base.rb` y `lib/docker_swarm/models/**/*` (justificación: PascalCase fiel a Docker API)

Sin `.ruby-version` en el repo. Ruby de runtime se infiere del gemspec (`>= 3.2.0`) y CI fija `3.4.4`.

## 4. CI/CD

### `.github/workflows/main.yml`

Workflow `Ruby` — corre en `push` a `main` y en cada `pull_request`.

- Runner: `ubuntu-latest`
- Matrix Ruby: `['3.4.4']`
- Steps: checkout (`actions/checkout@v6`, `persist-credentials: false`) → `ruby/setup-ruby@v1` con `bundler-cache: true` → `bundle exec rspec --tag ~type:integration` → `bundle exec rubocop`
- Tests de integración (`type:integration`) excluidos en CI — requieren Docker Engine real, correr local.

### `.github/workflows/release.yml`

Workflow `Publish to RubyGems` — corre en push de tag `v*`.

- Runner: `ubuntu-latest`
- Permisos: `contents: read`, `packages: write`
- Steps: checkout → setup Ruby 3.4.4 → `gem build *.gemspec` → `gem push *.gem`
- Secret requerido: `RUBYGEMS_API_KEY`
- Trigger manual: pushear tag `v<version>` (ver `/gem-release`).

## 5. Dependencias automatizadas

### `.github/dependabot.yml`

Dos ecosistemas:

- `bundler` (`/`): semanal, máx 10 PRs abiertos. Grupo `development-dependencies` agrupa `rubocop*`, `rspec*`, `pry*` en un sólo PR.
- `github-actions` (`/`): mensual.

## 6. Agentes / Skills

### `skills.yml`

Declara MCPs y skills externas a sincronizar.

- MCPs: `github`, `clickup`
- Skills (todas `repo: sequre/ai_knowledge` excepto donde se indique): `yard`, `quality-code`, `gem-release`, `dev-structure`, `dev-compose`, `dev-enrich`, `skill-feedback`, `agent-issue`, `dev-flow`, `matrix-element`, `documentation-writer` (`repo: github/awesome-copilot`, `path: skills/documentation-writer`)
- `matrix-element` consume env `MATRIX_AUTH_TOKEN` + homeserver `https://matrix.cloud.wispro.co` + room `agents`.

### `skills.lock`

Lock de skills sincronizadas (`synced_at: 2026-04-07`). Todas con `scope: local` y path en `.agents/skills/`. Regenerable con `ruby .agents/skills/skill-manager/scripts/sync.rb`.

### `.claude/settings.local.json`

Permisos locales de Claude Code (no versionar credenciales acá). Allow:

- `Bash(find /Users/gabriel/src/gems/docker-swarm/spec/integration -type f -name "*_spec.rb" -exec wc -l {} \\;)`
- `Bash(grep "^[[:space:]]*class " /Users/gabriel/src/gems/docker-swarm/lib/docker_swarm/**/*.rb)`
- `Bash(git rm *)`
- `Bash(bundle exec *)`

### `.claude/commands/*.md`

Slash commands del proyecto. Cuatro archivos: `api.md`, `errors.md`, `orm.md`, `test.md`. Invocables como `/api`, `/errors`, `/orm`, `/test` desde Claude Code.

## 7. Entorno local

### `.env`

**No versionado** (`.gitignore`). Variables ClickUp para reporting de agentes:

- `AI_REPORTS_SPACE_ID`, `AI_REPORTS_BUG_REPORTS_LIST_ID`, `AI_REPORTS_IMPROVEMENTS_LIST_ID`
- `AGENT_REVIEW_SAPCE_ID` (sic, typo), `AGENT_LIST_ID`, `AGENT_ACTION_PLAN_LIST_ID`

### `.gitignore`

Ignora: `.agents/` (skills sincronizadas, regenerables) y `.env` (variables de entorno).

## 8. Tabla resumen

| Archivo | Dominio | Consumidor | Versionado |
|---|---|---|---|
| `docker-swarm.gemspec` | Gema | Bundler / RubyGems | sí |
| `Gemfile` | Gema | Bundler | sí |
| `Gemfile.lock` | Gema | Bundler | sí |
| `.rubocop.yml` | Lint | RuboCop | sí |
| `.github/workflows/main.yml` | CI | GitHub Actions | sí |
| `.github/workflows/release.yml` | CD | GitHub Actions | sí |
| `.github/dependabot.yml` | Deps auto | GitHub Dependabot | sí |
| `skills.yml` | Skills | `skill-manager` | sí |
| `skills.lock` | Skills | `skill-manager` | sí |
| `.claude/settings.local.json` | Agente | Claude Code | sí |
| `.claude/commands/*.md` | Agente | Claude Code | sí |
| `.env` | Entorno | runtime local | **no** |
| `.gitignore` | VCS | git | sí |

## 9. Secrets / credenciales

- GitHub Actions: `RUBYGEMS_API_KEY` (release.yml)
- Local `.env`: IDs ClickUp (no secretos pero específicos del workspace)
- Skills `matrix-element`: `MATRIX_AUTH_TOKEN`

Ninguna credencial hardcodeada en archivos versionados.
