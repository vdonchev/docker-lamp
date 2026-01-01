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
| **PHP_VERSION**    | PHP version to use (e.g. `php83`, `php82`).                             |
| **PHP_IMAGE_TAG**  | Optional Docker image tag override for PHP. Leave empty to use default. |
| **ENABLE_XDEBUG**  | Enables Xdebug extension when set to `true`.                            |
| **SQL_ENGINE**     | Database engine (`mysql` or `mariadb`).                                 |
| **SQL_VERSION**    | Database version (e.g. `8.4` for MySQL).                                |
| **SQL_PORT**       | Host port mapped to the database container.                             |
| **SQL_ROOT_PWD**   | Root password for the database server.                                  |
| **SQL_DATA_PATH**  | Path on the host for persistent database storage.                       |
| **WEB_ROOT**       | Path to your local web project directory (document root).               |
| **HTTP_PORT**      | HTTP port exposed on the host (default `80`).                           |
| **HTTPS_PORT**     | HTTPS port exposed on the host (default `443`).                         |
| **PMA_PORT**       | phpMyAdmin port on the host (default `8080`).                           |
| **GIT_USER_NAME**  | Git username injected into the container for commits.                   |
| **GIT_USER_EMAIL** | Git email injected into the container for commits.                      |

**Note:**  
Changes to `PHP_VERSION`, `PHP_IMAGE_TAG`, or `GIT_USER_*` variables **require rebuilding** the lamp_web image,  
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
| **PHP_VERSION** | Defines the PHP version to use (e.g. `php83`, `php82`). Determines which base image and configuration files are applied. |
| **PHP_IMAGE_TAG** | Optional tag to specify a custom PHP image variant. Leave empty to use the default tag. |

**Note:**  
Changes to these `.env` variables **require rebuilding** the lamp_web image because they define the base PHP environment:

```bash
docker compose build lamp_web
docker compose up -d lamp_web
```

### PHP Image Tag

The `PHP_IMAGE_TAG` variable in `.env` allows you to lock the **exact** PHP image version used by the Apache container.  
This is optional — by default, the image tag is derived automatically from `PHP_VERSION`.

**How it works:**
- If `PHP_IMAGE_TAG` is **empty**, Docker uses the base image matching your major/minor PHP version.  
  Example:  
  PHP_VERSION=php84  
  → resolves to image `php:8.4-apache`
- If you **set** `PHP_IMAGE_TAG`, it overrides the automatic tag to pin a specific PHP patch version.  
  Example:  
  PHP_VERSION=php84  
  PHP_IMAGE_TAG=8.4.4  
  → resolves to image `php:8.4.4-apache`

**When to use it:**
- To ensure every developer and CI environment runs the exact same PHP build.
- When a specific patch release is required (e.g., for regression or dependency stability).

**When to leave it empty:**
- During active development, when you want to automatically track the latest patch version for your PHP branch.

**Note:**  
Changes to these `.env` variables **require rebuilding** the lamp_web image,  
as they determine the base image and build-time configuration:

```bash
docker compose up -d --build lamp_web
```

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
- When enabled, the entrypoint automatically adjusts PHP configuration to include `/usr/local/etc/php/conf.d/xdebug.ini`.
- No image rebuild is required — only a container restart.


## Configuring MySQL or MariaDB

---

### .env variables

| Variable | Description |
|-----------|--------------|
| **SQL_ENGINE** | Database engine to use — `mysql` or `mariadb`. Determines which image and configuration files are applied. |
| **SQL_VERSION** | Version of the selected SQL engine (e.g. `8.4` for MySQL or `11.3` for MariaDB). |
| **SQL_PORT** | Host port mapped to the database container’s internal port (default `3306`). |
| **SQL_ROOT_PWD** | Root password for the database server. Used for administration and phpMyAdmin access. |
| **SQL_DATA_PATH** | Absolute path on the host where database data is stored persistently. Example: `/home/your-user/db-data`. |

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

**Notes:**
- Based on `node:22` image.
- Project source is mounted from `${WEB_ROOT:-./app}` to `/projects`.
- Runs in idle mode (`tail -f /dev/null`) so you can exec into it freely.

### phpMyAdmin (`lamp_pma`)

Web-based interface for managing the MySQL or MariaDB database.

**Configuration (.env):**
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

**Start / Stop:**

    docker compose --profile with-redis up -d
    docker compose stop lamp_redis

**Access:**
- Host: `lamp_redis`
- Port: `6379`

**Notes:**
- Data persisted via `redis-data` volume.
- No authentication enabled by default (dev use only).

### Mailpit (`lamp_mailpit`)

Local SMTP testing tool with web interface for viewing captured emails.

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

both `localhost` and `app.test` will also be available over HTTPS:

    https://localhost
    https://app.test

This provides secure local access without additional configuration.  
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
The LAMP stack supports secure local HTTPS for all configured domains.  
Certificates are generated automatically using scripts provided in the repository — one for **Linux/macOS** and one for **Windows**.

Generated certificates are stored in:

    config/apache/ssl/dev.crt
    config/apache/ssl/dev.key

Once created, all local domains (such as `localhost` and `app.test`) can be accessed securely via:

    https://localhost
    https://app.test

### 1. Generating SSL on Linux or macOS

The included shell script automatically builds a multi-domain certificate  
based on your domain mappings in:

- `config/projects/domains.local.conf`

**Run from the project root:**

    ./scripts/generate-ssl.sh

The script:
- Collects all domains from the project config files.
- Creates a self-signed certificate valid for 10 years.
- Supports multiple SAN (Subject Alternative Name) entries for all defined domains.
- Saves the result in `config/apache/ssl/`.

If `openssl` is not installed, install it via your package manager:

- **Ubuntu/Debian:**

      sudo apt install openssl

- **macOS (Homebrew):**

      brew install openssl

Once generated, restart the web container:

    docker compose restart lamp_web

### 2. Generating SSL on Windows

Windows users can run the PowerShell version:

    scripts\generate-multidomain-ssl.ps1

**Requirements:**
- PowerShell 5.0 or newer.
- OpenSSL 3+ available in your system `PATH`.

The script:
- Reads all domains from the same config files.
- Automatically builds a self-signed multi-domain certificate.
- Stores it as:

      config\apache\ssl\dev.crt
      config\apache\ssl\dev.key

After generation, restart your web container:

    docker compose restart lamp_web

### 3. Installing the Certificate (Optional but Recommended)

To remove browser HTTPS warnings, you can trust the generated certificate locally.

#### Linux
    sudo cp config/apache/ssl/dev.crt /usr/local/share/ca-certificates/dev.crt
    sudo update-ca-certificates

#### macOS
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain config/apache/ssl/dev.crt

#### Windows
1. Double-click `dev.crt`
2. Click **Install Certificate**
3. Choose **Local Machine**
4. Place it in **Trusted Root Certification Authorities**

After installation, restart your browser to apply trust settings.

### 4. Regeneration

You can regenerate the certificate at any time if:
- New domains are added to `domains.local.conf`.
- The existing certificate expires or becomes invalid.

Simply rerun the same script, install generated certificate and restart the container. 

    docker compose restart lamp_web

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
| `make restart` | Restarts core containers (web + db). |
| `make restart-all` | Restarts all containers, including optional services. |
| `make status` | Displays running containers and their states. |

### Starting Optional Services

Each optional container is part of a **Docker Compose profile**, allowing selective startup.

| Command | Description |
|----------|-------------|
| `make up-node` | Starts Node.js container (`lamp_node`). |
| `make up-pma` | Starts phpMyAdmin (`lamp_pma`). |
| `make up-redis` | Starts Redis server (`lamp_redis`). |
| `make up-mailpit` | Starts Mailpit email testing tool (`lamp_mailpit`). |
| `make up-all` | Starts all services: web, db, phpMyAdmin, Redis, and Mailpit. |

### Building and Switching Versions

| Command | Description |
|----------|-------------|
| `make build` | Builds all containers using cache. |
| `make build-no-cache` | Builds all containers without using cache. |
| `make switch-php` | Rebuilds `lamp_web` after changing PHP version or tag in `.env`. |

### Logs and Debugging

| Command | Description |
|----------|-------------|
| `make logs` | Streams logs for all containers. |
| `make logs-web` | Shows Apache web container logs. |
| `make logs-db` | Shows SQL container logs. |
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
| `make cert` | Generates a new local multi-domain SSL certificate (see [SSL Certificates](#ssl-certificates)). |
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

**Regenerate SSL and restart web container:**

    make cert
    docker compose restart lamp_web

**Clean logs:**

    make clean-log

The Makefile is optional but highly recommended — it provides a fast and consistent way to manage your development stack across environments.

## Additional Shared Mounts


The PHP (Apache) container supports up to **five optional shared mounts**,  
allowing you to link extra folders from your host system directly into the container.  
This is useful for sharing configuration files, assets, or common project data between services or containers.


### Predefined Shares in `docker-compose.yml`

In the `lamp_web` service, the following mounts are defined:

    lamp_web:
      volumes:
        - ${EXTRA_SHARED_1:-/dev/null}:/mnt/shared1
        - ${EXTRA_SHARED_2:-/dev/null}:/mnt/shared2
        - ${EXTRA_SHARED_3:-/dev/null}:/mnt/shared3
        - ${EXTRA_SHARED_4:-/dev/null}:/mnt/shared4
        - ${EXTRA_SHARED_5:-/dev/null}:/mnt/shared5

If a variable is **unset or empty**, the mount points fallback to `/dev/null`,  
effectively disabling the share.


### How to Enable a Shared Mount

Edit your `.env` file and define one or more paths:

    EXTRA_SHARED_1=/home/user/shared/config
    EXTRA_SHARED_2=/home/user/shared/assets

Then restart the container to apply the changes:

    docker compose restart lamp_web

These paths will appear inside the container as:

    /mnt/shared1  →  /home/user/shared/config
    /mnt/shared2  →  /home/user/shared/assets

You can verify the mounted volumes inside the container:

    docker compose exec lamp_web mount | grep /mnt/shared


### Typical Use Cases

| Purpose | Example Path | Mounted To |
|----------|---------------|------------|
| Shared configuration or environment files | `/home/user/shared/config` | `/mnt/shared1` |
| Common uploads or storage directory | `/home/user/shared/storage` | `/mnt/shared2` |
| Composer cache or vendor mirror | `/home/user/.composer` | `/mnt/shared3` |
| Shared PHP libraries | `/home/user/php-libs` | `/mnt/shared4` |
| Integration with external service | `/home/user/tools` | `/mnt/shared5` |


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

A file named `install.example.sh` is included in:

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

       cp config/php/custom/install.example.sh config/php/custom/install.sh

2. Edit it to include your custom installation steps (extensions, packages, etc.).
3. Rebuild the web container:

       docker compose build lamp_web

### Notes

- Scripts must be executable (`chmod +x`).
- They run **only at build time**, not at container startup.
- Use this mechanism for project-specific image extensions or dependencies.
