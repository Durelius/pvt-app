#!/usr/bin/env bash
# Runs all manual test scenarios against the local middle service.
# Results are saved to manual_test/results/YYYY-MM-DD_HHMM.md
#
# Usage:
#   bash manual_test/run.sh
#
# Prerequisites: middle service must be running on localhost:8080.
# Start it with:
#   SL_DATA_DIR=backend/services/middle/data \
#   SERVICE_NAME=middle \
#   PLACES_KEY=$(grep PLACES_KEY .env | cut -d= -f2) \
#   go run ./backend/services/middle/app/main.go

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
OUT="$RESULTS_DIR/$TIMESTAMP.md"
BASE_URL="http://localhost:8080/api/middle/v1"

mkdir -p "$RESULTS_DIR"

if ! curl -sf "$BASE_URL/health" > /dev/null 2>&1; then
  echo "ERROR: Middle service not running on localhost:8080."
  echo ""
  echo "Start it with:"
  echo "  SL_DATA_DIR=backend/services/middle/data \\"
  echo "  SERVICE_NAME=middle \\"
  echo "  PLACES_KEY=\$(grep PLACES_KEY .env | cut -d= -f2) \\"
  echo "  go run ./backend/services/middle/app/main.go"
  exit 1
fi

run_scenario() {
  local name="$1"
  local desc="$2"
  local points="$3"
  local type="$4"

  echo "  Running: $name..." >&2
  local result
  result=$(curl -sf "$BASE_URL/middleplaces?location_type=$type" \
    --get --data-urlencode "points=$points")

  printf "## %s\n\n" "$name"
  printf "**Type:** \`%s\`  \n" "$type"
  printf "**Inputs:** %s\n\n" "$desc"
  printf "| # | Place | Address | Rating | Coords |\n"
  printf "|---|-------|---------|--------|--------|\n"
  echo "$result" | jq -r '
    to_entries[] |
    "| \(.key + 1) | \(.value.displayName.text) | \(.value.formattedAddress) | \(.value.rating) | \(.value.location.latitude | tostring | .[0:7]),\(.value.location.longitude | tostring | .[0:7]) |"
  '
  printf "\n"
}

{
  printf "# Manual Test Results\n\n"
  printf "**Date:** %s  \n" "$TIMESTAMP"
  printf "**Branch:** %s  \n" "$(git rev-parse --abbrev-ref HEAD)"
  printf "**Commit:** %s  \n\n" "$(git rev-parse --short HEAD)"
  echo "---"
  echo ""

  run_scenario \
    "3 people: Södermalm / Östermalm / Kungsholmen → restaurant" \
    "Södermalm (59.3145,18.0715), Östermalm (59.3400,18.0800), Kungsholmen (59.3320,18.0200)" \
    '[{"lat":59.3145,"lon":18.0715},{"lat":59.3400,"lon":18.0800},{"lat":59.3320,"lon":18.0200}]' \
    "restaurant"

  run_scenario \
    "3 people: Vasastan / Södermalm / Lidingö → cafe" \
    "Vasastan (59.3450,18.0490), Södermalm (59.3145,18.0715), Lidingö (59.3650,18.1500)" \
    '[{"lat":59.3450,"lon":18.0490},{"lat":59.3145,"lon":18.0715},{"lat":59.3650,"lon":18.1500}]' \
    "cafe"

  run_scenario \
    "2 people: Vällingby (west) / Nacka (east) → restaurant" \
    "Vällingby (59.3625,17.8710), Nacka (59.3113,18.1632)" \
    '[{"lat":59.3625,"lon":17.8710},{"lat":59.3113,"lon":18.1632}]' \
    "restaurant"

  run_scenario \
    "4 people: Bromma / Farsta / Täby / Nacka → restaurant" \
    "Bromma (59.3547,17.9372), Farsta (59.2427,18.0900), Täby (59.4310,18.0690), Nacka (59.3113,18.1632)" \
    '[{"lat":59.3547,"lon":17.9372},{"lat":59.2427,"lon":18.0900},{"lat":59.4310,"lon":18.0690},{"lat":59.3113,"lon":18.1632}]' \
    "restaurant"

} > "$OUT"

echo "Results saved to $OUT"
