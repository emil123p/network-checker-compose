# Network Checker Compose

A lightweight TCP connectivity monitoring tool running in Docker.

## Features

- Periodically checks TCP connectivity to a configurable host on port 443.
- Records timestamped results in a log file.
- Runs continuously using Docker Compose.
- Restarts automatically according to the container restart policy.
- Generates monitoring reports for the last hour or 24 hours.
- Validates Python syntax and Docker Compose configuration with GitHub Actions.
- Supports a pull-based deployment workflow for applying merged configuration updates.

## Architecture

- **Docker image:** `ghcr.io/emil123p/network-checker:<version-tag>`
- **Container orchestration:** Docker Compose
- **Monitoring loop:** `monitor.sh`
- **Report generation:** `raport.py`
- **CI validation:** GitHub Actions
- **Deployment update script:** `deploy-update.sh`

Monitoring results are stored in `logs/wyniki.log` on the host and persist across container restarts.

## Requirements

- Ubuntu or another Linux distribution
- Docker Engine
- Docker Compose
- Git
- Internet connectivity to the monitored host and GitHub

## Configuration

The following environment variables can be configured in the local `.env` file:

| Variable | Default | Description |
|---|---|---|
| `CHECK_HOST` | `github.com` | Host to monitor |
| `CHECK_INTERVAL` | `30` | Interval between checks, in seconds |
| `CHECK_TIMEOUT` | `3` | Connection timeout, in seconds |

The `.env` file contains host-specific settings and should not be committed if it contains local configuration.

## Usage

Start monitoring in the background:

```bash
docker compose up -d
```

Check container status:

```bash
docker compose ps
```

Follow container logs:

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

GitHub Actions runs validation on pushes to `main` and pull requests targeting `main`.

The workflow checks Python syntax and validates the Docker Compose configuration.

The application repository also builds and publishes Docker images to GitHub Container Registry (GHCR).
When a new image is published, an event can trigger an update pull request in this deployment repository.
The deployment change is applied after that pull request is merged.

## Automatic Deployment Updates

The `deploy-update.sh` script checks the GitHub `main` branch for new commits.

The script:

1. Checks that the local Git working tree has no uncommitted changes.
2. Fetches the latest state of `main`.
3. Checks the commit history to avoid unexpected history changes.
4. Detects changes to `compose.yaml` and `monitor.sh`.
5. Validates the Compose configuration, pulls the image, and runs `docker compose up -d`
   when relevant files have changed.
6. Records the processed commit after a successful update.

Run the script manually from the repository directory:

```bash
./deploy-update.sh
```

If there are no new changes, the script exits without updating the running service.

### Deployment state

The last processed commit is stored locally on the Ubuntu host at:

`~/.local/state/network-checker-compose/last-deployed-commit`

This file is specific to the host and is not tracked by Git.
It records the deployment script's processing state; it is not a monitoring log.

### Host-local configuration and secrets

Some deployment-related files are stored outside the Git repository because they contain host-specific state
or sensitive credentials.

- `~/.local/state/network-checker-compose/last-deployed-commit` — records the last processed deployment commit.
- `~/.config/network-checker-compose/email.env` — stores Gmail SMTP credentials used for email notifications.
This file must never be committed to Git or shared publicly.

The configuration directory should have permissions `700`, and `email.env` should have permissions `600`,
restricting access to the owner.

These files are local to the Ubuntu host and are not tracked by Git.

### Periodic execution

A `systemd` service and timer are configured on the Ubuntu host.
Their source files are stored in the repository under `systemd/` and linked from `/etc/systemd/system/`.

The timer is enabled and starts automatically with Ubuntu.
It runs the deployment check approximately 2 minutes after boot and then every 5 minutes.

- Service: `network-checker-deploy.service`
- Timer: `network-checker-deploy.timer`

Check the timer schedule:

```bash
systemctl list-timers network-checker-deploy.timer
```

Check the service logs:

```bash
journalctl -u network-checker-deploy.service --no-pager
```

The host must be powered on and connected to the network for updates to be checked and deployed.
If it is powered off, checks resume after the next startup.

### Deployment failure notifications

If `network-checker-deploy.service` fails, systemd triggers `network-checker-notify-failure.service`,
which runs `scripts/notify-deployment-failure.py` and sends an email through Gmail SMTP.

The notification includes the host name, UTC timestamp, and a command for inspecting deployment logs.
It indicates a deployment process failure; it does not necessarily mean the application itself is unavailable.

Inspect deployment logs:

```bash
sudo journalctl -u network-checker-deploy.service --no-pager
```

Check the notification service:

```bash
sudo systemctl status network-checker-notify-failure.service --no-pager
```

SMTP credentials are stored outside the repository in `~/.config/network-checker-compose/email.env`. Never commit or share this file.

## Limitations

- Monitoring and automatic deployment checks are available only while the host is running
  and connected to the network.
- The tool checks TCP connectivity on port 443; it does not verify the full health of an application or website.
- Deployment automation depends on the GitHub repository, Docker, and access to the published image.

## Project Status

This is a hands-on DevOps learning project focused on containerization, monitoring, Git,
CI automation, and deployment workflows.

---

# Network Checker Compose — wersja polska

Lekkie narzędzie do monitorowania łączności TCP, uruchamiane w Dockerze.

## Funkcje

- Okresowo sprawdza połączenie TCP z konfigurowanym hostem na porcie 443.
- Zapisuje wyniki wraz ze znacznikami czasu.
- Działa w tle za pomocą Docker Compose.
- Automatycznie uruchamia ponownie kontener zgodnie z jego polityką restartów.
- Generuje raporty z ostatniej godziny lub 24 godzin.
- Sprawdza składnię Pythona i konfigurację Docker Compose za pomocą GitHub Actions.
- Obsługuje model wdrażania, w którym serwer sam pobiera zmiany z repozytorium.

## Architektura

- **Obraz Dockera:** `ghcr.io/emil123p/network-checker:<tag-wersji>`
- **Zarządzanie kontenerami:** Docker Compose
- **Pętla monitorująca:** `monitor.sh`
- **Generowanie raportów:** `raport.py`
- **Walidacja CI:** GitHub Actions
- **Skrypt aktualizacyjny:** `deploy-update.sh`

Wyniki monitorowania są przechowywane na hoście w pliku `logs/wyniki.log`
i zachowują się po ponownym uruchomieniu kontenera.

## Wymagania

- Ubuntu lub inna dystrybucja Linuksa
- Docker Engine
- Docker Compose
- Git
- Połączenie z internetem umożliwiające dostęp do monitorowanego hosta i GitHuba

## Konfiguracja

Poniższe zmienne środowiskowe można ustawić w lokalnym pliku `.env`:

| Zmienna | Wartość domyślna | Opis |
|---|---|---|
| `CHECK_HOST` | `github.com` | Monitorowany host |
| `CHECK_INTERVAL` | `30` | Odstęp między sprawdzeniami w sekundach |
| `CHECK_TIMEOUT` | `3` | Limit czasu na nawiązanie połączenia w sekundach |

Plik `.env` zawiera ustawienia konkretnego środowiska i nie powinien być dodawany do repozytorium,
jeśli przechowuje lokalną konfigurację.

## Obsługa

Uruchom monitorowanie w tle:

```bash
docker compose up -d
```

Sprawdź stan kontenera:

```bash
docker compose ps
```

Wyświetl logi kontenera na bieżąco:

```bash
docker compose logs -f
```

Zatrzymaj monitorowanie:

```bash
docker compose down
```

## Raporty

Raport z ostatniej godziny:

```bash
python3 raport.py 1h
```

Raport z ostatnich 24 godzin:

```bash
python3 raport.py 24h
```

Raporty korzystają z historycznych danych zapisanych w `logs/wyniki.log`.

## Ciągła integracja (CI)

GitHub Actions uruchamia walidację po wypchnięciu zmian do gałęzi `main` oraz dla pull requestów
kierowanych do tej gałęzi.

Workflow sprawdza składnię Pythona i poprawność konfiguracji Docker Compose.

Repozytorium aplikacji buduje również obrazy Dockera i publikuje je w GitHub Container Registry (GHCR).
Po opublikowaniu nowego obrazu zdarzenie może uruchomić workflow tworzący pull request aktualizujący
wersję obrazu w tym repozytorium. Zmiana zostaje wdrożona po scaleniu pull requesta.

## Automatyczne aktualizacje wdrożenia

Skrypt `deploy-update.sh` sprawdza, czy w gałęzi `main` na GitHubie pojawiły się nowe commity.

Skrypt:

1. Sprawdza, czy lokalne repozytorium nie zawiera niezapisanych zmian.
2. Pobiera aktualny stan gałęzi `main`.
3. Kontroluje historię commitów, aby wykryć nieoczekiwane zmiany.
4. Sprawdza, czy zmieniły się pliki `compose.yaml` lub `monitor.sh`.
5. Jeśli zmiany dotyczą tych plików, sprawdza konfigurację Compose, pobiera obraz
   i wykonuje `docker compose up -d`.
6. Po pomyślnej aktualizacji zapisuje przetworzony commit.

Ręczne uruchomienie skryptu z katalogu repozytorium:

```bash
./deploy-update.sh
```

Jeśli nie ma nowych zmian, skrypt kończy działanie bez aktualizowania działającej usługi.

### Informacja o stanie wdrożenia

Ostatni przetworzony commit jest zapisywany lokalnie na hoście Ubuntu w pliku:

`~/.local/state/network-checker-compose/last-deployed-commit`

Plik dotyczy konkretnego hosta i nie jest śledzony przez Git. Przechowuje stan przetwarzania wdrożenia,
a nie wyniki monitorowania.

### Lokalna konfiguracja i dane poufne

Niektóre pliki związane z wdrożeniem są przechowywane poza repozytorium Git,
ponieważ zawierają stan konkretnego hosta lub poufne dane logowania.

- `~/.local/state/network-checker-compose/last-deployed-commit` — przechowuje informację
  o ostatnim przetworzonym commicie wdrożenia.
- `~/.config/network-checker-compose/email.env` — przechowuje dane logowania Gmail SMTP wykorzystywane
  do wysyłania powiadomień e-mail. Tego pliku nie wolno dodawać do Git ani udostępniać publicznie.

Katalog konfiguracyjny powinien mieć uprawnienia `700`, a plik `email.env` — `600`.
Ogranicza to dostęp do właściciela.

Pliki te są lokalne dla hosta Ubuntu i nie są śledzone przez Git.

### Okresowe uruchamianie

Usługa i timer `systemd` są skonfigurowane na hoście Ubuntu.
Pliki źródłowe znajdują się w repozytorium w katalogu `systemd/` i są dowiązane z katalogu `/etc/systemd/system/`.

Timer jest włączony i uruchamia się automatycznie wraz z Ubuntu.
Pierwsze sprawdzenie aktualizacji następuje około 2 minuty po starcie systemu, a kolejne co 5 minut.

- Usługa: `network-checker-deploy.service`
- Timer: `network-checker-deploy.timer`

Sprawdzenie harmonogramu timera:

```bash
systemctl list-timers network-checker-deploy.timer
```

Sprawdzenie logów usługi:

```bash
journalctl -u network-checker-deploy.service --no-pager
```

Host musi być włączony i połączony z siecią, aby sprawdzać i wdrażać aktualizacje.
Gdy jest wyłączony, sprawdzanie zostaje wznowione po kolejnym uruchomieniu systemu.

### Powiadomienia o błędach wdrożenia

Jeśli `network-checker-deploy.service` zakończy się błędem, systemd uruchamia
`network-checker-notify-failure.service`, która wykonuje skrypt `scripts/notify-deployment-failure.py`
i wysyła e-mail przez Gmail SMTP.

Powiadomienie zawiera nazwę hosta, czas UTC oraz polecenie umożliwiające sprawdzenie logów wdrożenia.
Oznacza błąd procesu wdrażania, ale nie musi oznaczać, że sama aplikacja jest niedostępna.

Wyświetlenie logów wdrożenia:

```bash
sudo journalctl -u network-checker-deploy.service --no-pager
```

Sprawdzenie usługi powiadomień:

```bash
sudo systemctl status network-checker-notify-failure.service --no-pager
```

Dane SMTP są przechowywane poza repozytorium w pliku `~/.config/network-checker-compose/email.env`.
Nie wolno dodawać tego pliku do Git ani go udostępniać.

## Ograniczenia

- Monitorowanie i automatyczne sprawdzanie aktualizacji są możliwe tylko wtedy, gdy host jest włączony
  i połączony z siecią.
- Narzędzie sprawdza łączność TCP na porcie 443; nie weryfikuje pełnej sprawności aplikacji
  ani strony internetowej.
- Automatyzacja wdrożeń wymaga dostępu do GitHuba, Dockera i opublikowanego obrazu.

## Status projektu

Jest to praktyczny projekt edukacyjny DevOps obejmujący konteneryzację, monitorowanie, Git,
automatyzację CI oraz proces wdrażania zmian.
