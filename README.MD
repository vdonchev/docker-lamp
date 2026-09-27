# Docker LAMP Stack for Devs

A modern, flexible, lightweight, and developer-friendly LAMP (Linux, Apache, MySQL/MariaDB, PHP) stack designed for
local development.  
Supports multiple PHP and SQL versions, virtual hosts with HTTPS, and optional tools like phpMyAdmin, Redis, and
Mailpit.

Easily configurable via `.env`, with clean structure and no bloat.

It’s especially well-suited for multi-project development scenarios.
Local domains and automatic virtual host generation make it easy to run and switch between multiple projects seamlessly
on the same environment.

## Requirements

---

- **Docker** with **Docker Compose** (Compose V2 CLI plugin is recommended)
- **Bash** – required for running provided scripts and Makefile targets (Linux/macOS/WSL)

_Optional but recommended:_

- **GNU Make** – to use the Makefile shortcuts (optional but makes life easier)

This stack is built and extensively tested on Linux and WSL2.
It should work on macOS and Docker Desktop for Windows, assuming paths and permissions are correctly handled.

## Installation

---
We provide a few ways to get started, depending on your OS and preferences.

## Linux | WSL | macOS

Manual installation:

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
cp example.env .env
# Edit the .env file to match your local project path, PHP/SQL versions, ports, etc.
docker compose up -d
```

Using the bash **init.sh** script:

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
scripts/init.sh
# Then edit the .env file if needed
docker compose up -d
```

If **GNU Make** is available:

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
make init
# Then edit the .env file if needed
make up
```

## Windows (PowerShell)

Manual installation:

```shell
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp; cd docker-lamp
Copy-Item example.win.env .env
# Edit the .env file to match your local project path, PHP/SQL versions, ports, etc.
docker compose up -d
```

Using the **init.ps1** script:

```shell
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp; cd docker-lamp
.\scripts\init.ps1
# Then edit the .env file if needed
docker compose up -d
```

***Important note:***  
`make` commands do **not** work correctly in **PowerShell** or **CMD** because the provided `Makefile` uses POSIX shell syntax.  
Run all `make` commands from **Git Bash** or another Unix-like shell instead.

## Configuration

---
By default, two example `.env` files are included: **example.env** (for Linux/macOS/WSL) and **example.win.env** (
optimized for native Windows).  
Copy the appropriate one to `.env` in the project root.

### .env variables

| Variable           | Description                                                             |
|--------------------|-------------------------------------------------------------------------|
| **PHP_VERSION**    | PHP version to use (e.g. `php85`, `php84`, `php83`).                    |
| **PHP_IMAGE_TAG**  | Optional Docker image tag override for PHP. Leave empty to use default. |
| **WP_CLI_VERSION** | Optional WP-CLI version pin, e.g. `2.12.0` (default `latest`).           |
| **ENABLE_XDEBUG**  | Enables Xdebug extension when set to `true`.                            |
| **NODE_VERSION**   | Node Docker image tag for the optional `lamp_node` container.           |
| **REDIS_VERSION**  | Optional Redis image tag, e.g. `8.10` (default `latest`).                |
| **PMA_VERSION**    | Optional phpMyAdmin image tag, e.g. `5.2.3` (default `latest`).          |
| **MAILPIT_VERSION** | Optional Mailpit image tag, e.g. `v1.31.3` (default `latest`).           |
| **SQL_ENGINE**     | Database engine (`mysql` or `mariadb`).                                 |
| **SQL_VERSION**    | Database version (e.g. `8.4` for MySQL).                                |
| **SQL_PORT**       | Host port mapped to the database container.                             |
| **SQL_ROOT_PWD**   | Root password for the database server.                                  |
| **SQL_DATA_PATH**  | Path on the host for persistent database storage.                       |
| **WEB_ROOT**       | Path to your local web project directory (document root).               |
| **HTTP_PORT**      | HTTP port exposed on the host (default `80`).                           |
| **HTTPS_PORT**     | HTTPS port exposed on the host (default `443`).                         |
| **PMA_PORT**       | phpMyAdmin port on the host (default `8080`).                           |
| **GIT_USER_NAME**  | Git username injected into PHP 7+ containers for commits.                |
| **GIT_USER_EMAIL** | Git email injected into PHP 7+ containers for commits.                   |

**Note:**  
Changes to `PHP_VERSION`, `PHP_IMAGE_TAG`, `WP_CLI_VERSION`, or `GIT_USER_*` variables **require rebuilding** the lamp_web image,
as they are used during the build process:
```bash
docker compose build lamp_web
docker compose up -d lamp_web
```

## Configuring PHP

---
### .env variables

| Variable | Description |
|-----------|--------------|
| **PHP_VERSION** | Defines the PHP version to use (e.g. `php85`, `php84`, `php83`). Determines which base image and configuration files are applied. |
| **PHP_IMAGE_TAG** | Optional tag to specify a custom PHP image variant. Leave empty to use the default tag. |
| **WP_CLI_VERSION** | Optional WP-CLI version pin for PHP 8+ images. Leave empty to install the latest stable release. |

PHP 8.2 through 8.5 are supported upstream. Older image directories remain available only for legacy projects and should not be used for new development.

**Note:**  
Changes to these `.env` variables **require rebuilding** the lamp_web image because they define the base PHP environment:

```bash
docker compose build lamp_web
docker compose up -d lamp_web
```

### PHP Image Tag

The `PHP_IMAGE_TAG` variable in `.env` allows you to select a PHP patch-level image tag for the Apache container.
This is optional — by default, the image tag is derived automatically from `PHP_VERSION`.

**How it works:**
- If `PHP_IMAGE_TAG` is **empty**, Docker uses the base image matching your major/minor PHP version.  
  Example:  
  PHP_VERSION=php85
  → resolves to image `php:8.5-apache`
- If you **set** `PHP_IMAGE_TAG`, it overrides the automatic tag to pin a specific PHP patch version.  
  Example:  
  PHP_VERSION=php85
  PHP_IMAGE_TAG=8.5.11
  → resolves to image `php:8.5.11-apache`

**When to use it:**
- To keep developers and CI on the same PHP patch tag.
- When a specific patch release is required (e.g., for regression or dependency stability).

Docker tags can be republished. A patch-level tag improves consistency but is not an immutable content lock.

**When to leave it empty:**
- During active development, when you want to automatically track the latest patch version for your PHP branch.

**Note:**  
Changes to these `.env` variables **require rebuilding** the lamp_web image,  
as they determine the base image and build-time configuration:

```bash
docker compose up -d --build lamp_web
```

### WP-CLI

[WP-CLI](https://wp-cli.org/) is preinstalled in all PHP 8+ web images at `/usr/local/bin/wp`, which is included in the container's `PATH`.
Run it directly inside the web container:

```bash
docker compose exec lamp_web wp --info
docker compose exec lamp_web wp core version
```

From an interactive shell, use the `wp` command directly:

```bash
make shell
wp --info
```

The latest stable release is installed by default. To pin a specific release, set its version in `.env` and rebuild the web image:

```dotenv
WP_CLI_VERSION=2.12.0
```

```bash
docker compose up -d --build lamp_web
```

WP-CLI `2.12.0` can emit an upstream PHP deprecation warning on PHP 8.5, but the command still runs successfully.

### Configuration files

Default PHP settings are defined in `./config/php/conf.d/php.ini`.  
To override or extend these settings, create a file named `./config/php/conf.d/php.local.ini`.  
This file is loaded after the default configuration and will override any conflicting values.

**Note:**  
`./config/php/conf.d/php.local.ini` is copied into the container during the startup process.  
If you modify this file, you must restart the container with `--force-recreate` flag:

```bash
docker compose up -d --force-recreate lamp_web
```

### Enabling Xdebug

Xdebug is preinstalled in the PHP container but **disabled by default**.

To enable it, edit your `.env` file and set:

    ENABLE_XDEBUG=true

Then restart the PHP container for the change to take effect:

    docker compose restart lamp_web

**Notes:**
- When `ENABLE_XDEBUG=false` (default), Xdebug is not loaded.
- When enabled, the entrypoint automatically creates `/usr/local/etc/php/conf.d/100-xdebug.ini`.
- No image rebuild is required — only a container restart.


## Configuring MySQL or MariaDB

---

### .env variables

| Variable | Description |
|-----------|--------------|
| **SQL_ENGINE** | Database engine to use — `mysql` or `mariadb`. Determines which image and configuration files are applied. |
| **SQL_VERSION** | Version of the selected SQL engine (e.g. `8.4` for MySQL or `12.3` for MariaDB). |
| **SQL_PORT** | Host port mapped to the database container’s internal port (default `3306`). |
| **SQL_ROOT_PWD** | Root password for the database server. Used for administration and phpMyAdmin access. |
| **SQL_DATA_PATH** | Absolute path on the host where database data is stored persistently. Example: `/home/your-user/db-data`. |

Database directories are separated by engine and major/minor version. Patch tags in the same branch, such as `8.4` and `8.4.11`, use the same directory.

**Note:**  
Changes to `.env` variables do **not** require rebuilding the container images.  
However, you must restart the containers for the new values to take effect:

```bash
docker compose up -d lamp_db
```

### Configuration files

The default database configuration depends on the SQL engine set in your `.env` file.  
Based on that value, the corresponding default `my.cnf` file is loaded automatically.

To override or extend the configuration, create a file at:  
`./config/sql/SQL_ENGINE/my.local.cnf`

**Note:**  
`./config/sql/SQL_ENGINE/my.local.cnf` is copied into the container during the startup process.  
If you modify this file, you must restart the container with `--force-recreate` flag:

```bash
docker compose up -d --force-recreate lamp_db
```

## Additional Containers

---
This LAMP stack defines several optional service containers to enhance local development.  
Each service can be started or stopped independently using Docker Compose profiles.

### Node (`lamp_node`)

Provides a Node.js environment for frontend tooling (npm, yarn, vite, webpack, etc.).  
Useful for compiling assets and running build pipelines.

**Start / Stop:**

    docker compose --profile with-node up -d
    docker compose stop lamp_node

**Usage examples:**

    docker compose run --rm lamp_node npm install
    docker compose run --rm lamp_node npm run dev
    docker compose run --rm lamp_node yarn install
    docker compose run --rm lamp_node yarn dev

**Configuration (.env):**
- `NODE_VERSION=24` — Node Docker image tag used by `lamp_node`.
- For legacy frontend stacks, override this value (e.g. `NODE_VERSION=14.21.3`).

**Notes:**
- Based on `node:${NODE_VERSION:-24}` image.
- Project source is mounted from `${WEB_ROOT:-./app}` to `/projects`.
- Runs in idle mode (`tail -f /dev/null`) so you can exec into it freely.

### phpMyAdmin (`lamp_pma`)

Web-based interface for managing the MySQL or MariaDB database.

**Configuration (.env):**
- `PMA_VERSION` — optional phpMyAdmin Docker image tag; leave empty to use `latest` (example: `PMA_VERSION=5.2.3`).
- `PMA_PORT=8080` — port for phpMyAdmin web interface.

**Start / Stop:**

    docker compose --profile with-pma up -d
    docker compose stop lamp_pma

**Access:**
- Open `http://localhost:8080`
- Login with credentials defined by `SQL_ROOT_PWD`.

**Notes:**
- Connected automatically to the `lamp_db` service.
- Optional local domain can be added to `/etc/hosts` (e.g., `pma.localhost` → `127.0.0.1`).

### Redis (`lamp_redis`)

In-memory key–value store for caching, sessions, and queues.

**Configuration (.env):**
- `REDIS_VERSION` — optional Redis Docker image tag; leave empty to use `latest` (example: `REDIS_VERSION=8.10`).

**Start / Stop:**

    docker compose --profile with-redis up -d
    docker compose stop lamp_redis

**Access:**
- Host: `lamp_redis`
- Port: `6379`

**Notes:**
- Data persisted via `redis-data` volume.
- No authentication enabled by default (dev use only).
- Using `latest` can cross major Redis versions; pin a tag when data compatibility matters.

### Mailpit (`lamp_mailpit`)

Local SMTP testing tool with web interface for viewing captured emails.

**Configuration (.env):**
- `MAILPIT_VERSION` — optional Mailpit Docker image tag; leave empty to use `latest` (example: `MAILPIT_VERSION=v1.31.3`).

**Ports (.env):**
- `8025` — Web UI.
- `1025` — SMTP input.

**Start / Stop:**

    docker compose --profile with-mailpit up -d
    docker compose stop lamp_mailpit

**Access:**
- Web UI: `http://localhost:8025`
- SMTP endpoint: `lamp_mailpit:1025`

**Notes:**
- Captures outgoing mail for inspection.
- No external delivery; intended for local testing.

### Profiles Overview

Each optional service is grouped under a **profile** for selective startup.

| Profile name | Includes service | Command to start |
|---------------|------------------|------------------|
| `with-node`   | `lamp_node`      | `docker compose --profile with-node up -d` |
| `with-pma`    | `lamp_pma`       | `docker compose --profile with-pma up -d` |
| `with-redis`  | `lamp_redis`     | `docker compose --profile with-redis up -d` |
| `with-mailpit`| `lamp_mailpit`   | `docker compose --profile with-mailpit up -d` |

You can combine multiple profiles, for example:

    docker compose --profile with-pma --profile with-mailpit up -d


## Using the LAMP Stack

This stack supports **two main workflows**:

1. Developing a **single application**
2. Running **multiple projects simultaneously** under separate local domains

---

### 1. Single Project Mode

Use this mode when you’re working on one application only — for example, a single Symfony or Laravel project.

In your `.env` file, set the project root path:

    WEB_ROOT=/home/user/projects/myapp

When the container starts:
- Apache automatically serves files from that directory.
- The project is accessible at:

      http://localhost

By default, the domain **`app.test`** is included in `config/projects/domains.conf`.  
If you add it to your system hosts file:

    127.0.0.1 app.test

you can access the project at:

    http://app.test

If local SSL certificates are present in:

    config/apache/ssl/dev.crt
    config/apache/ssl/dev.key

configured domains such as `app.test` will also be available over HTTPS:

    https://app.test

`localhost` is not added automatically; only domains in the project domain files are included in the certificate.
➡ **Read more:** see the [SSL Certificates](#ssl-certificates) for details on how to generate and configure local certificates.

### 2. Multi-Project Mode

If you develop several applications at once (for example `api`, `admin`, `shop`),  
the stack can host all of them through domain-based virtual hosts.

This mode uses the **vhost generation system**, which reads configuration files  
and automatically creates a separate Apache vhost for each defined project.

Refer to the section below for full details.

### Local Domains and Virtual Hosts

When the `lamp_web` container starts, the entrypoint executes:

    /scripts/generate-vhosts.sh

The script:
1. Reads project → domain mappings
2. Loads Apache templates
3. Adds HTTPS vhosts if SSL certificates are found
4. Writes the generated configs to:

   config/apache/vhosts/generated/

Apache then loads these automatically.

### Configuration Structure

| Purpose | Editable File | Default Template |
|----------|----------------|------------------|
| Domain → project mapping | `config/projects/domains.local.conf` | `config/projects/domains.conf` |
| Apache directives | `config/apache/vhosts/vhost.local.conf` | `config/apache/vhosts/vhost.conf` |

The `.local.` files are for developer use — they override the defaults and are ignored by Git.

### Defining Projects

Each domain mapping line follows:

    domain-name,absolute-path

Example (`config/projects/domains.local.conf`):

    app.localhost,/var/www/app/public
    api.localhost,/var/www/api/public

Then add your domains to `/etc/hosts`:

    127.0.0.1 app.localhost api.localhost

Restart the web container to regenerate vhosts:

    docker compose restart lamp_web

### Custom Apache Settings

Custom PHP or Apache directives can be added in:

    config/apache/vhosts/vhost.local.conf

Example:

    <Directory /var/www/app/public>
        AllowOverride All
        Require all granted
        php_value upload_max_filesize 64M
        php_value post_max_size 64M
    </Directory>

### HTTPS Support

If both of these files exist:

    config/apache/ssl/dev.crt
    config/apache/ssl/dev.key

the generator automatically enables HTTPS vhosts for every domain,  
making all projects accessible over both `http://` and `https://`.

### Typical Workflow for Multi-Project Mode

1. Define your projects in `config/projects/domains.local.conf`
2. (Optional) Adjust Apache behavior in `config/apache/vhosts/vhost.local.conf`
3. Add your domains to `/etc/hosts`
4. Restart the web container:

        docker compose restart lamp_web

5. Access your projects via their local domains, e.g.  
   `http://app.localhost`, `http://api.localhost`

### Generated Files

All final vhost configs are written into:

    config/apache/vhosts/generated/

They include:
- `000-vhost.local.conf` — local Apache overrides
- `100-domains.conf` — generated project mappings
- `999-vhost.conf` — base defaults

These files are regenerated automatically each time the container starts.

## SSL Certificates

---
The stack creates a persistent local development CA and uses it to sign a replaceable multi-domain server certificate. Trust the CA once; adding domains or renewing the server certificate does not require reinstalling host trust.

Private signing material stays on the host and is ignored by Git:

    var/local-ca/dev-ca.crt
    var/local-ca/dev-ca.key
    var/local-ca/dev-ca.srl

Apache receives only the public CA copy and server certificate files:

    config/apache/ssl/dev-ca.crt
    config/apache/ssl/dev.crt
    config/apache/ssl/dev.key

The CA key is never mounted into `lamp_web`. At startup, `lamp_web` installs only `dev-ca.crt` into its system trust store so PHP and cURL can verify local HTTPS services normally.

### Generate or Renew Certificates

Add mappings to `config/projects/domains.local.conf`, then run:

    make cert

The first run creates the persistent CA. Every run issues a fresh server certificate containing all valid, deduplicated domains from `domains.conf` and `domains.local.conf`. If `lamp_web` is running, `make cert` restarts it automatically.

Without Make, use the platform script and restart the container:

    ./scripts/generate-multidomain-ssl.sh
    docker compose restart lamp_web

Native Windows PowerShell:

    & .\scripts\generate-multidomain-ssl.ps1
    docker compose restart lamp_web

OpenSSL must be available in `PATH`. The generated leaf uses SAN names and is valid only for configured domains; `localhost` is not included unless explicitly mapped.

Verify the CA, server purpose, and matching private key with:

    make cert-verify

Native Windows can verify the certificate chain with:

    openssl verify -CAfile .\config\apache\ssl\dev-ca.crt -purpose sslserver .\config\apache\ssl\dev.crt

### Trust the CA on the Host

The trust helpers validate the CA, display its SHA256 fingerprint, and require typed confirmation. They never install the server leaf certificate.

Linux, macOS, or WSL (WSL installs into Windows Current User trust):

    make cert-trust-host

Automated Linux trust uses Debian/Ubuntu-style `update-ca-certificates`. Other distributions receive an explicit error and should install `config/apache/ssl/dev-ca.crt` with their distribution's CA trust tooling.

Native Windows PowerShell:

    & .\scripts\manage-windows-ca-trust.ps1 -Action install -CertificatePath .\config\apache\ssl\dev-ca.crt

Restart open browsers after changing trust. Firefox may use its own certificate store depending on its configuration; enable enterprise roots or import `config/apache/ssl/dev-ca.crt` into Firefox Authorities if it still warns.

To remove this exact CA:

    make cert-untrust-host

Native Windows PowerShell:

    & .\scripts\manage-windows-ca-trust.ps1 -Action remove -CertificatePath .\config\apache\ssl\dev-ca.crt

### CA Rotation

Normal certificate generation never rotates the CA. If rotation is deliberately required:

1. Remove the old CA from host trust with `make cert-untrust-host`.
2. Run `make cert-rotate-ca` and type the requested confirmation.
3. Trust the new CA with `make cert-trust-host`.
4. Restart open browsers.

On native Windows, use the PowerShell trust commands above before and after `& .\scripts\generate-multidomain-ssl.ps1 -RotateCa`.

## Makefile Reference
***Important note:***  
`make` commands do **not** work correctly in **PowerShell** or **CMD** because the provided `Makefile` uses POSIX shell syntax.  
If on Windows, run all `make` commands from **Git Bash** or another Unix-like shell instead.
---

The provided **Makefile** simplifies managing the full LAMP environment.  
It wraps `docker compose` commands into short, consistent targets for building, running, restarting, logging, and maintenance.

Run:

    make help

to see all available commands with descriptions.


### Basic Lifecycle Commands

| Command | Description |
|----------|-------------|
| `make init` | Initializes the project environment (`scripts/init.sh` on Linux/macOS, `init.ps1` on Windows). |
| `make up` | Starts core containers: Apache (`lamp_web`) and SQL (`lamp_db`). |
| `make down` | Stops and removes all containers, volumes, and orphaned networks. |
| `make restart` | Restarts the services that are currently running, including optional profile services. |
| `make restart-all` | Restarts all containers, including optional services. |
| `make status` | Displays running containers and their states. |

`make restart` preserves the active service set and does not remove containers or volumes. If no services are running, it starts the core `lamp_web` and `lamp_db` services.

### Starting Optional Services

Each optional container is part of a **Docker Compose profile**, allowing selective startup.

| Command | Description |
|----------|-------------|
| `make up-node` | Starts Node.js container (`lamp_node`). |
| `make up-pma` | Starts phpMyAdmin (`lamp_pma`). |
| `make up-redis` | Starts Redis server (`lamp_redis`). |
| `make up-mailpit` | Starts Mailpit email testing tool (`lamp_mailpit`). |
| `make up-all` | Starts all services: web, db, Node.js, phpMyAdmin, Redis, and Mailpit. |

### Building and Switching Versions

| Command | Description |
|----------|-------------|
| `make build` | Builds all containers using cache. |
| `make build-no-cache` | Builds all containers without using cache. |
| `make switch-php` | Rebuilds `lamp_web` after changing PHP version or tag in `.env`, while preserving all currently running services. |
| `make rebuild` | Alias for `make switch-php`; rebuilds `lamp_web` while preserving all currently running services. |

Both rebuild commands fall back to starting `lamp_web` and `lamp_db` when no services are running. Optional services that were already running remain running after the web container is rebuilt.

### Logs and Debugging

| Command | Description |
|----------|-------------|
| `make logs` | Streams logs for all containers. |
| `make logs-web` | Shows Apache web container logs. |
| `make logs-db` | Shows SQL container logs. |
| `make logs-node` | Shows Node.js container logs. |
| `make logs-pma` | Shows phpMyAdmin logs. |
| `make logs-redis` | Shows Redis logs. |
| `make logs-mailpit` | Shows Mailpit logs. |
| `make logs-php` | Filters and displays only PHP errors from `var/log/apache/error.log`. |

### Shell Access and CLI Tools

| Command | Description |
|----------|-------------|
| `make shell` | Opens an interactive bash shell in the web container (`lamp_web`). |
| `make shell-db` | Opens a shell session inside the database container. |
| `make shell-node` | Opens a shell inside the Node.js container. |
| `make cli-db` | Opens MySQL CLI connected as root inside the db container. |

### Maintenance and Utilities

| Command | Description |
|----------|-------------|
| `make clean-log` | Deletes and recreates the `./var/log` directory. |
| `make cert` | Generates a CA-signed multi-domain certificate and restarts `lamp_web` if running. |
| `make cert-verify` | Verifies the local CA, server certificate purpose, and private key. |
| `make cert-trust-host` | Installs the CA into Linux/macOS host trust or Windows trust from WSL. |
| `make cert-untrust-host` | Removes the exact Docker LAMP CA from host trust. |
| `make cert-rotate-ca` | Explicitly rotates the CA after confirmation. |
| `make fix-perms` | Reapplies executable permissions to all shell scripts. |

### Help Command

| Command | Description |
|----------|-------------|
| `make help` | Displays all available Makefile commands with descriptions. |

### Example Workflows

**Start core stack:**

    make up

**Start full stack with extras:**

    make up-all

**Change PHP version and rebuild:**

    make switch-php

**Regenerate SSL and restart the web container if it is running:**

    make cert

**Clean logs:**

    make clean-log

The Makefile is optional but highly recommended — it provides a fast and consistent way to manage your development stack across environments.

## Additional Shared Mounts


The PHP (Apache) container supports up to **ten optional shared mounts**,
allowing you to link extra folders from your host system directly into the container.  
This is useful for sharing configuration files, assets, or common project data between services or containers.


### Predefined Shares in `docker-compose.yml`

In the `lamp_web` service, the following mounts are defined:

    lamp_web:
      volumes:
        - ${EXTRA_SHARED_0:-/dev/null}:/mnt/shared0
        - ${EXTRA_SHARED_1:-/dev/null}:/mnt/shared1
        - ${EXTRA_SHARED_2:-/dev/null}:/mnt/shared2
        - ${EXTRA_SHARED_3:-/dev/null}:/mnt/shared3
        - ${EXTRA_SHARED_4:-/dev/null}:/mnt/shared4
        - ${EXTRA_SHARED_5:-/dev/null}:/mnt/shared5
        - ${EXTRA_SHARED_6:-/dev/null}:/mnt/shared6
        - ${EXTRA_SHARED_7:-/dev/null}:/mnt/shared7
        - ${EXTRA_SHARED_8:-/dev/null}:/mnt/shared8
        - ${EXTRA_SHARED_9:-/dev/null}:/mnt/shared9

If a variable is **unset or empty**, the mount points fallback to `/dev/null`,  
effectively disabling the share.


### How to Enable a Shared Mount

Edit your `.env` file and define one or more paths:

    EXTRA_SHARED_0=/home/user/shared/config
    EXTRA_SHARED_1=/home/user/shared/assets

Then restart the container to apply the changes:

    docker compose restart lamp_web

These paths will appear inside the container as:

    /mnt/shared0  →  /home/user/shared/config
    /mnt/shared1  →  /home/user/shared/assets

You can verify the mounted volumes inside the container:

    docker compose exec lamp_web mount | grep /mnt/shared


### Typical Use Cases

| Purpose | Example Path | Mounted To |
|----------|---------------|------------|
| Shared configuration or environment files | `/home/user/shared/config` | `/mnt/shared0` |
| Common uploads or storage directory | `/home/user/shared/storage` | `/mnt/shared1` |
| Composer cache or vendor mirror | `/home/user/.composer` | `/mnt/shared2` |
| Shared PHP libraries | `/home/user/php-libs` | `/mnt/shared3` |
| Integration with external service | `/home/user/tools` | `/mnt/shared4` |


### Notes

- All paths must be **absolute host paths**.
- Restarting the container is enough to apply changes; rebuild is not required.
- The `/mnt/sharedX` directories are writable by default inside the container.
- You can use them freely in your application configuration or scripts.

This approach provides flexibility for extending or integrating your local environment  
without modifying the main container or Compose setup.

## Extending the PHP (lamp_web) Container

The PHP image includes a **custom install hook** that automatically runs shell scripts  
from the `config/php/custom/` directory during the build process.  
This mechanism allows you to add extra packages, PHP extensions, or any setup logic  
without changing the main Dockerfile of lamp_web.

### Default Example

A file named `install.example` is included in:

    config/php/custom/

It provides a ready-to-use template with commented examples.  
To activate it, simply copy or rename it to `install.sh` (or any `.sh` filename).

### How It Works

- All `.sh` files inside `config/php/custom/` are executed automatically during build.
- Execution order is alphabetical.
- Each script runs inside the PHP image during its build phase.
- Output from each script is visible in the Docker build logs.

### Usage

1. Duplicate the example file:

       cp config/php/custom/install.example config/php/custom/install.sh

2. Edit it to include your custom installation steps (extensions, packages, etc.).
3. Rebuild the web container:

       docker compose build lamp_web

### Notes

- Scripts must be executable (`chmod +x`).
- They run **only at build time**, not at container startup.
- Use this mechanism for project-specific image extensions or dependencies.
