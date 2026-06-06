# PVT App (mitten)

Find the best place to meet. Given the locations of several people, the app
ranks nearby venues by how fairly they split everyone's public-transport
travel time — minimizing the *spread* between the person with the longest trip
and the person with the shortest.

The backend is a set of small Go services behind an API gateway, computing
transit times on an in-memory graph built from SL (Stockholm) GTFS data, with
Google Places and OpenStreetMap as venue sources. The frontend is a Flutter app
(iOS, Android, and web) using Mapbox for maps and Google Sign-In for auth.

---

## Architecture

```
                 ┌──────────────┐
  Flutter app ──▶│ api-gateway  │  :8080   (reverse proxy + CORS + rate limit)
                 └──────┬───────┘
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
       ┌──────┐    ┌─────────┐   ┌──────────┐
       │ auth │    │ middle  │   │  user    │
       │:8081 │    │ :8082   │   │ :8084    │
       └──────┘    └─────────┘   └──────────┘
                        │              │
                  SL graph +      PostgreSQL
                  Places/OSM        (db:5432)
```

| Service       | Role                                                          | Host port |
|---------------|---------------------------------------------------------------|-----------|
| `api-gateway` | Single entry point; reverse-proxies to services, CORS, limits | 8080      |
| `auth`        | Auth endpoints                                                | 8081      |
| `middle`      | Core feature — midpoint + transit ranking (`/middleplaces`)   | 8082      |
| `user`        | Users, profiles, friends, Google Sign-In login               | 8084      |
| `db`          | PostgreSQL 16                                                 | 5432      |

> The current backend services are `auth`, `middle`, and `user`. Dropping a new
> service into `backend/services/` automatically adds it to the generated
> compose file on the next `make generate`.

> Ports for the backend services are assigned automatically (gateway on
> `BASE_PORT`, each service on the next port up) — see the generation flow below.

For a full file-level breakdown see [`doc/backend_structure.md`](doc/backend_structure.md)
and [`doc/scripts_docker_structure.md`](doc/scripts_docker_structure.md).

---

## Prerequisites

- **Docker** + Docker Compose (backend)
- **Go 1.25** (only if running services outside Docker)
- **Flutter** (frontend) with Xcode (iOS) and/or Android SDK (Android)
- API keys: a Google Places key and a Mapbox access token

---

## Environment setup

Copy the template and fill in the values:

```bash
cp .env.example .env
```

Key variables (see `.env.example` for the full annotated list):

| Variable               | Purpose                                                          |
|------------------------|------------------------------------------------------------------|
| `BACKEND_URL`          | URL the app calls. `http://localhost:8080` (iOS/web), `http://10.0.2.2:8080` (Android emulator) |
| `PLACES_KEY`           | Google Places API key (private — never commit)                   |
| `MAPBOX_ACCESS_TOKEN`  | Mapbox token for maps                                            |
| `DB_HOST`/`DB_PORT`/…  | PostgreSQL connection (`DB_HOST=db` inside Docker)               |
| `JWT_SECRET`           | Token signing secret                                            |

---

## How the build works

The backend never ships a hand-written `docker-compose.yml` — it is **generated**
so that adding a new service under `backend/services/` automatically wires it in.

```
make            scripts/                      Docker                       runtime
─────           ─────────                     ───────                      ───────
make up    ─▶   generate-compose.sh    ─▶     DockerGateway / DockerService  ─▶  docker compose up
                (writes docker-compose.yml)   (dev images w/ hot-reload via air)
```

1. **`scripts/generate-compose.sh`** walks `backend/services/*/`, and for each
   one emits a service block in `docker-compose.yml`: the gateway gets
   `BASE_PORT` (default 8080), and every service gets the next port in sequence.
   Postgres and the persistent `db-data` volume are added too.
2. **Dockerfiles** are shared, not per-service:
   - `DockerGateway` / `DockerService` — dev images running [air](https://github.com/air-verse/air) for live reload.
   - `DockerGateway.prod` / `DockerService.prod` — multi-stage prod builds (compiled binary on `alpine`).
   - `DockerMiddle.prod` — prod override for `middle`; also copies the GTFS `data/` and sets `SL_DATA_DIR`.
3. **`docker compose`** builds and runs everything, mounting the repo at `/app`
   and loading `.env`.

The repo root is a single Go module (`go.mod` / `go.sum`); all services share
the `backend/shared/` packages (DB, router, models, auth middleware).

### Makefile commands

| Command            | What it does                                                                 |
|--------------------|------------------------------------------------------------------------------|
| `make generate`    | Regenerate `docker-compose.yml` from the services on disk                    |
| `make up`          | `generate` + `docker compose up` (start the backend)                         |
| `make build`       | `generate` + `docker compose up --build` (rebuild images, then start)        |
| `make down`        | `docker compose down`                                                        |
| `make flutter`     | Run the Flutter app (regenerates splash, `pub get`, `flutter run`)           |
| `make flutter-dev` | Same as `flutter` but with `--dart-define=DEV=true`                          |
| `make flutter-web` | Run on Chrome at a fixed host/port for Google Sign-In (see below)            |
| `make ios`         | Launch the iOS simulator (`flutter emulators --launch apple_ios_simulator`)  |
| `make android`     | Launch the first available Android AVD (`emulator -avd …`)                   |

Override the base port if 8080 is taken:

```bash
make up BASE_PORT=9000
```

---

## Running the frontend

Start the backend first (`make up`), then launch the app on your target.

### iOS simulator

```bash
make ios          # boots the iOS simulator
make flutter      # builds and runs the app on it
```

Use `BACKEND_URL=http://localhost:8080` in `.env` for the iOS simulator.

### Android emulator

```bash
make android      # boots the first AVD from `emulator -list-avds`
make flutter      # builds and runs the app on it
```

The Android emulator reaches your host machine via `10.0.2.2`, so set
`BACKEND_URL=http://10.0.2.2:8080` in `.env`.

### Web + Google Sign-In

```bash
make flutter-web
```

This runs the app in Chrome pinned to **`localhost:58555`**:

```bash
flutter run -d chrome --web-hostname localhost --web-port 58555
```

The fixed host and port matter: Google OAuth only completes for **authorized
JavaScript origins** registered on the OAuth client. `http://localhost:58555`
is one of those registered origins, so Google Sign-In works on web only when the
app is served from this exact address. Letting Flutter pick a random port would
break the sign-in redirect.

---

## CI/CD pipeline

Defined in [`.github/workflows/deploy-backend.yml`](.github/workflows/deploy-backend.yml).
It runs on pushes to `main` that touch `backend/**`, the prod Dockerfiles, or
`scripts/generate-compose.prod.sh` (and can be triggered manually via
`workflow_dispatch`).

**Job 1 — Build & Push.** Logs in to GitHub Container Registry (`ghcr.io`),
mirrors `postgres:16`, then builds and pushes one image per service from the
`.prod` Dockerfiles (`middle` uses `DockerMiddle.prod`, the rest
`DockerService.prod`), tagged `latest` under `ghcr.io/<owner>/pvt-<service>`.

**Job 2 — Deploy** (environment `production`, after the build succeeds):

1. Runs **`scripts/generate-compose.prod.sh`** with `IMAGE_PREFIX` set, producing
   a `docker-compose.prod.yml` that references the pushed registry images (with
   `restart`, memory limits, and log rotation). *(Without `IMAGE_PREFIX` the same
   script falls back to building locally from the `.prod` Dockerfiles.)*
2. SSHes to the Linode VPS, copies the compose file via `rsync`, and writes the
   server `.env` (`PLACES_KEY`, `MAPBOX_ACCESS_TOKEN`) from GitHub secrets.
3. `docker compose pull` + `up -d --remove-orphans`, then prunes old images
   (and prunes harder if disk usage exceeds 70%).

So the prod flow mirrors local dev — Makefile/generate-compose for dev, the
GitHub Action + `generate-compose.prod.sh` for prod — just with compiled images
deployed onto the VPS instead of hot-reloading containers.

Required GitHub config: secrets `SSH_KEY`, `PLACES_KEY`, `MAPBOX_ACCESS_TOKEN`
(and the built-in `GITHUB_TOKEN`); variables `LINODE_IP`, `DEPLOY_USER`.

---

## Project layout

```
pvt-app/
├── Makefile                  # dev/build shortcuts
├── docker-compose.yml        # generated — do not edit by hand
├── DockerGateway[.prod]       # gateway images (dev / prod)
├── DockerService[.prod]       # shared service images (dev / prod)
├── DockerMiddle.prod          # prod middle image (bundles GTFS data)
├── scripts/
│   ├── generate-compose.sh        # dev compose generator
│   ├── generate-compose.prod.sh   # prod compose generator
│   └── validate_midpoint.sh       # midpoint output validation
├── .github/workflows/
│   └── deploy-backend.yml     # CI/CD: build → push → deploy
├── backend/
│   ├── api-gateway/           # reverse proxy
│   ├── services/              # auth, middle, user, …
│   └── shared/                # db, router, models, middleware
├── frontend/                  # Flutter app (mitten)
└── doc/                       # architecture & structure docs
```
