# Docker LAMP Stack

A modern, flexible, lightweight, and developer-friendly LAMP (Linux, Apache, MySQL/MariaDB, PHP) stack designed for local development.  
Supports multiple PHP and SQL versions, virtual hosts with HTTPS, and optional tools like phpMyAdmin, Redis, and Mailpit.

Easily configurable via `.env`, with clean structure and no bloat.
          
## Features

- **Multiple PHP and SQL versions**  
  Easily switch between PHP 5.6 to 8.4, and MySQL or MariaDB versions, without changing the stack configuration.

- **Fully `.env`-configurable**  
  Set project paths, ports, service versions, and credentials in one place — no need to touch Docker files.

- **Modular and profile-based**  
  Optional services like phpMyAdmin, Redis, and Mailpit can be toggled on or off using Docker Compose profiles.

- **Apache with SSL and virtual host generator**  
  Ships with auto-generated self-signed certificates and dynamic Apache virtual host support.

- **Local domain support**  
  Designed to work seamlessly with local dev domains like `project.test`, including automatic HTTPS.

- **Multi-project ready**  
  Run multiple isolated projects side-by-side, each with its own codebase, configuration, and virtual host.

- **Structured and minimal by design**  
  Clean file hierarchy with dedicated folders for config, logs, scripts, and runtime data — no clutter, no assumptions.

- **Custom entrypoints for web and database containers**  
  Run your own pre-init scripts or setup logic inside PHP and SQL containers before the main service starts.

## Requirements

- **Docker** – version 20.10 or later
- **Docker Compose** – version 2.0 or later (Compose V2 CLI plugin is recommended)
- **Bash** – required for running provided scripts and Makefile targets (Linux/macOS/WSL)

Optional but recommended:
- **GNU Make** – to use the Makefile shortcuts (optional but makes life easier)

This stack is built and tested on Linux and WSL2. It should work on macOS and Docker Desktop for Windows, assuming paths and permissions are correctly handled.


## Installation

Like it simple? Sure, we do too. Pick the setup style that fits your workflow.

### Manual setup

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
cp example.env .env
# Edit the .env file to match your local project path, PHP/SQL versions, ports, etc.
docker compose up -d
```

### Using the bash init script

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
scripts/.init.sh
# Then edit the .env file if needed
docker compose up -d
```

### If GNU Make is available

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
make init
make up
```

All paths lead to the same place — a ready-to-code local LAMP stack with just a few commands.
