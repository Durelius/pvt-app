# Scripts, Makefile & Docker Structure

```
pvt-app/
│
├── Makefile                          # Build / run / dev shortcuts
│
├── .env                              # Local secrets (not committed)
├── .env.example                      # Template for required env vars
├── .env.public.example               # Template for non-secret env vars
│
├── docker-compose.yml                # Local dev: all services + postgres
│
├── DockerGateway                     # Dev Dockerfile for api-gateway
├── DockerGateway.prod                # Prod Dockerfile for api-gateway
├── DockerService                     # Dev Dockerfile for all backend services
├── DockerService.prod                # Prod Dockerfile for all backend services
├── DockerMiddle.prod                 # Prod Dockerfile override for middle service
│
├── .github/
│   └── workflows/
│       └── deploy-backend.yml        # CI/CD pipeline (backend deploy)
│
├── scripts/
│   ├── generate-compose.sh           # Generates docker-compose.yml for dev
│   ├── generate-compose.prod.sh      # Generates docker-compose.yml for prod
│   └── validate_midpoint.sh          # Validates midpoint calculation output
│
└── manual_test/
    ├── README.md                     # Manual test instructions
    ├── run.sh                        # Runs the manual test suite
    └── results/
        └── 2026-05-11_0711.md        # Saved test run results
```

---


Creation and running of the backend: makefile -> generate-compose.sh -> creating dockergateway, dockerservice, dockermiddle and docker-compose -> executing the docker compose.
same in prod but with .prod files, github action runs the deploy-backend.yml which runs the generate-compose.prod.sh and deploys on VPS
## Docker Services (docker-compose.yml)

| Service           | Dockerfile        | Host Port | Internal Port | Depends On     |
|-------------------|-------------------|-----------|---------------|----------------|
| api-gateway       | DockerGateway     | 8080      | 8080          | db (healthy)   |
| auth              | DockerService     | 8081      | 8080          | db (healthy)   |
| middle            | DockerService     | 8082      | 8080          | db (healthy)   |
| sl                | DockerService     | 8083      | 8080          | db (healthy)   |
| user              | DockerService     | 8084      | 8080          | db (healthy)   |
| db (postgres:16)  | official image    | 5432      | 5432          | —              |

All services mount the repo root as `/app` and load environment variables from `.env`.  
The `db` volume (`db-data`) persists PostgreSQL data across container restarts.

---

## Dockerfile Variants

| File                | Purpose                                                  |
|---------------------|----------------------------------------------------------|
| `DockerGateway`     | Dev build for api-gateway (with hot-reload via air)      |
| `DockerGateway.prod`| Prod build for api-gateway (optimised, no hot-reload)    |
| `DockerService`     | Dev build shared by auth, middle, sl, user, signinverif  |
| `DockerService.prod`| Prod build shared by the same services                   |
| `DockerMiddle.prod` | Prod build override for middle (includes GTFS data/)     |
