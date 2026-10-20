# Network Checker Compose

A lightweight TCP connectivity monitoring tool running in Docker.

## Features

- Periodically checks TCP connectivity to a configurable host on port 443.
- Records timestamped results in a log file.
- Runs continuously using Docker Compose.
- Restarts automatically according to the container restart policy.
- Generates monitoring reports for the last hour or 24 hours.
- Validates Python syntax and Docker Compose configuration with GitHub Actions.

## Architecture

- **Docker image:** `ghcr.io/emil123p/network-checker:latest`
- **Container orchestration:** Docker Compose
- **Monitoring loop:** `monitor.sh`
- **Report generation:** `raport.py`
- **CI validation:** GitHub Actions

Monitoring results are stored in `logs/wyniki.log` on the host and persist across container restarts.

## Requirements

- Docker Engine
- Docker Compose
- Internet connectivity to the monitored host

## Configuration

The following environment variables can be configured:

| Variable | Default | Description |
|---|---|---|
| `CHECK_HOST` | `github.com` | Host to monitor |
| `CHECK_INTERVAL` | `30` | Interval between checks, in seconds |

## Usage

Start monitoring in the background:

```bash
docker compose up -d
```

Check container status:

```bash
docker compose ps
```

Follow monitoring logs:

```bash
docker compose logs -f
```

Stop monitoring:

```bash
docker compose down
```

## Reports

Generate a report for the last hour:

```bash
python3 raport.py 1h
```

Generate a report for the last 24 hours:

```bash
python3 raport.py 24h
```

Reports use the historical data stored in `logs/wyniki.log`.

## Continuous Integration

GitHub Actions runs on pushes to `main` and pull requests targeting `main`.

The workflow checks Python syntax and validates the Docker Compose configuration.

## Limitations

Monitoring is available only while the host running Docker is powered on and connected to the network. The tool checks TCP connectivity on port 443; it does not verify the full health of an application or website.

## Project status

This is a hands-on DevOps learning project focused on containerization, monitoring, Git, and CI automation.
