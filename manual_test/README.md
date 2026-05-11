# Manual Test Instructions

This directory contains a repeatable test script for the middle service's transit-time ranking.
Run it after algorithm changes to compare results over time.

## How to run

### 1. Start the middle service locally

From the project root:

```bash
SL_DATA_DIR=backend/services/middle/data \
SERVICE_NAME=middle \
PLACES_KEY=$(grep PLACES_KEY .env | cut -d= -f2) \
go run ./backend/services/middle/app/main.go
```

Wait for: `SL graph loaded: 443 stops, 137825 edges`

### 2. Run the test script

```bash
bash manual_test/run.sh
```

Results are saved to `manual_test/results/YYYY-MM-DD_HHMM.md`.

## Test scenarios

| Scenario | People | Type | What to check |
|----------|--------|------|---------------|
| 3 inner-city | Södermalm, Östermalm, Kungsholmen | restaurant | Should land near Hötorget/City area |
| 3 with island | Vasastan, Södermalm, Lidingö | cafe | Should skew toward Östermalm (Lidingö transit hub) |
| 2 east–west | Vällingby, Nacka | restaurant | Should land in City/Gamla Stan area |
| 4 very spread | Bromma, Farsta, Täby, Nacka | restaurant | Södermalm or City — well-connected by all lines |

## How to interpret results

- **Geographic fit**: do the recommendations sit roughly between the input points, weighted by transit access?
- **Cluster tightness**: are top results close together (good) or scattered across the city (bad)?
- **Outliers**: any result far from the others in the list is suspicious — could indicate a routing or scoring bug.
- **SL API fallback**: if the server logs show many "SL API" lines, local routing may have gaps.

## File naming

`results/YYYY-MM-DD_HHMM.md` — one file per test run, git-tracked so diffs show regression/improvement over time.
