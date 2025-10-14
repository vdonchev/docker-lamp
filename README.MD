# Docker LAMP Stack for Devs

A modern, flexible, lightweight, and developer-friendly LAMP (Linux, Apache, MySQL/MariaDB, PHP) stack designed for local development.  
Supports multiple PHP and SQL versions, virtual hosts with HTTPS, and optional tools like phpMyAdmin, Redis, and Mailpit.

Easily configurable via `.env`, with clean structure and no bloat.

It’s especially well-suited for multi-project development scenarios.
Local domains and automatic virtual host generation make it easy to run and switch between multiple projects seamlessly on the same environment.

## Requirements

- **Docker** with **Docker Compose** (Compose V2 CLI plugin is recommended)
- **Bash** – required for running provided scripts and Makefile targets (Linux/macOS/WSL)

_Optional but recommended:_
- **GNU Make** – to use the Makefile shortcuts (optional but makes life easier)

This stack is built and extensively tested on Linux and WSL2.
It should work on macOS and Docker Desktop for Windows, assuming paths and permissions are correctly handled.


## Installation

Like it simple? Sure, we do too. Pick the setup style that fits your workflow.

### Manual setup (Recommended for Windows)

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
cp example.env .env
# Edit the .env file to match your local project path, PHP/SQL versions, ports, etc.
docker compose up -d
```

### Using the bash init script

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
scripts/init.sh
# Then edit the .env file if needed
docker compose up -d
```

### If GNU Make is available

```bash
git clone https://github.com/vdonchev/docker-lamp.git docker-lamp && cd docker-lamp
make init
make up
```