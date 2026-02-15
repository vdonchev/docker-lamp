# AGENTS.md
Guidance for coding agents working in this repository.
This repo is Dockerized local infrastructure (LAMP + optional services), not a single app codebase.

## Scope and Architecture
- Primary purpose: local dev stack for Apache/PHP + MySQL or MariaDB.
- Core orchestration: `docker-compose.yml` + `Makefile`.
- Main mutable logic: Bash/PowerShell scripts in `scripts/`.
- Optional containers: `lamp_node`, `lamp_redis`, `lamp_pma`, `lamp_mailpit`.
- Repo PHP (`app/index.php`) is only a placeholder landing page.
- Most application code normally lives in mounted `${WEB_ROOT}`.

## Important Paths
- `docker-compose.yml`: service topology, mounts, profiles.
- `Makefile`: preferred command entrypoint for local ops.
- `scripts/init.sh`, `scripts/init.ps1`: first-time bootstrap.
- `scripts/entrypoint/web.sh`, `scripts/entrypoint/sql.sh`: runtime startup logic.
- `scripts/generate-vhosts.sh`, `scripts/generate-multidomain-ssl.sh`: generated infra config.
- `bin/php/<phpXX>/Dockerfile`: PHP image definitions.
- `config/`: Apache/PHP/SQL defaults + local override locations.

## Cursor/Copilot Rule Status
- `.cursor/rules/`: not found.
- `.cursorrules`: not found.
- `.github/copilot-instructions.md`: not found.
- If added later, treat them as highest-priority repository instructions.

## Setup and Lifecycle Commands
Run from repo root.

```bash
make init
make up
make down
make up-node
make up-pma
make up-redis
make up-mailpit
make status
make logs-web
make logs-db
```

Direct Compose equivalents (when Make is unavailable):

```bash
docker compose up -d lamp_web lamp_db
docker compose --profile with-node up -d lamp_node
docker compose --profile with-pma up -d lamp_pma
docker compose --profile with-redis up -d lamp_redis
docker compose --profile with-mailpit up -d lamp_mailpit
```

## Build, Lint, and Test Commands
There is no native automated test suite for this infra repo today.
Validation = compose config check + script syntax checks + smoke startup.

### Build
```bash
make build
make build-no-cache
make switch-php
```

### Lint/Validation
```bash
docker compose config --quiet

bash -n scripts/init.sh
bash -n scripts/generate-vhosts.sh
bash -n scripts/generate-multidomain-ssl.sh
bash -n scripts/entrypoint/web.sh
bash -n scripts/entrypoint/sql.sh

# Optional if shellcheck is installed
shellcheck scripts/**/*.sh
```

### Smoke Test
```bash
make up
docker compose ps
make logs-web
```

### Running a Single Test (mounted app under `${WEB_ROOT}`)
Use these only if the mounted project includes the relevant test framework.

PHPUnit:
```bash
docker compose exec lamp_web php vendor/bin/phpunit tests/Feature/ExampleTest.php
docker compose exec lamp_web php vendor/bin/phpunit tests/Feature/ExampleTest.php --filter test_method_name
```

Pest:
```bash
docker compose exec lamp_web php vendor/bin/pest tests/Feature/ExampleTest.php
docker compose exec lamp_web php vendor/bin/pest --filter "test method name"
```

Frontend (Node profile enabled):
```bash
docker compose run --rm lamp_node npm test -- path/to/test.spec.ts
```

## Code Style Guidelines
Follow existing repo patterns first. Keep edits minimal, focused, and reversible.

### General
- Prefer local override files (`*.local.*`) over editing versioned defaults.
- Do not commit secrets (`.env`, private cert material, machine-specific paths).
- Preserve executable bits for scripts and keep scripts re-runnable.
- Keep naming descriptive and consistent with surrounding files.

### Bash (`scripts/*.sh`)
- Shebang: `#!/bin/bash`.
- Fail fast with `set -e` (or stricter only when matching file style).
- Quote variable expansions (`"$VAR"`) and command args.
- Prefer `[[ ... ]]` for conditionals and regex checks.
- Use small helper functions for non-trivial repeated logic.
- Use uppercase for env-derived globals/constants (`SQL_ENGINE`, `BASE_DIR`).
- Emit clear status/error messages with prefixes (`[init]`, `[OK]`, `[warn]`, `[error]`).
- Validate inputs early; exit non-zero on invalid config/state.

### PowerShell (`scripts/*.ps1`)
- Use `$ErrorActionPreference = "Stop"`.
- Guard file operations with `Test-Path`.
- Prefer explicit status lines (`[OK]`, `[WARN]`, `[ERROR]`).
- Keep functions single-purpose; return typed arrays where appropriate.

### Dockerfiles (`bin/php/*/Dockerfile`)
- Group apt installs to reduce layers when practical.
- Clean apt metadata in the same layer (`rm -rf /var/lib/apt/lists/*`).
- Keep PHP extension installs explicit and deterministic.
- Pin versions when stability matters (example: xdebug pin).
- Keep custom hooks predictable (`config/php/custom/*.sh` executes alphabetically).

### PHP (repo-local PHP)
- Target modern PHP 8+ style.
- Escape output by default (`htmlspecialchars`) when rendering HTML.
- Keep logic readable; avoid deep nesting.
- For new non-trivial files, prefer strict types and explicit param/return types.
- Imports: use explicit `use` statements, avoid repeated fully qualified names.
- Naming: `PascalCase` classes, `camelCase` methods/vars, `UPPER_SNAKE_CASE` constants.

## Config File Rules
- Respect banners like `DO NOT EDIT THIS FILE DIRECTLY`.
- Preferred customization points:
  - `config/apache/vhosts/vhost.local.conf`
  - `config/projects/domains.local.conf`
  - `config/php/conf.d/php.local.ini`
  - `config/sql/<engine>/my.local.cnf`

## Error Handling and Reliability
- Validate env-driven values before use (for example SQL engine whitelist).
- Fail fast on unsupported or malformed config.
- Keep startup scripts deterministic and idempotent.
- Be explicit about destructive actions (`make down` removes volumes/orphans).

## Agent Workflow
- Before editing behavior, read `Makefile`, `docker-compose.yml`, and touched scripts.
- Prefer `make` targets for standard operations; use raw `docker compose` when needed.
- After changing scripts/config, run validation commands and check relevant container logs.
