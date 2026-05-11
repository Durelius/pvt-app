#!/usr/bin/env bash
# Validates that the recommended midpoint places are actually equidistant
# (travel-time wise) from 3 input addresses.
#
# Uses:
#   - Production API (tidochplats.se) to get recommended places
#   - SL Journey Planner API for transit travel times
#
# Usage: ./scripts/validate_midpoint.sh

set -euo pipefail

API="${API:-https://tidochplats.se/api}"
SL="https://journeyplanner.integration.sl.se/v2/trips"

# ── Edit these 3 addresses ───────────────────────────────────────────────────
NAME1="Sundbyberg";  LAT1=59.3630; LON1=17.9740
NAME2="Södermalm";   LAT2=59.3180; LON2=18.0470
NAME3="Östermalm";   LAT3=59.3380; LON3=18.0880
# ─────────────────────────────────────────────────────────────────────────────

urlencode() { python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"; }

POINTS="[{\"lat\":$LAT1,\"lon\":$LON1},{\"lat\":$LAT2,\"lon\":$LON2},{\"lat\":$LAT3,\"lon\":$LON3}]"

echo "Fetching recommended places for:"
echo "  1. $NAME1 ($LAT1, $LON1)"
echo "  2. $NAME2 ($LAT2, $LON2)"
echo "  3. $NAME3 ($LAT3, $LON3)"
echo ""

RESPONSE=$(curl -sf "$API/middle/v1/middleplaces?points=$(urlencode "$POINTS")&location_type=restaurant")

COUNT=$(echo "$RESPONSE" | jq 'length')
if [[ "$COUNT" == "0" || -z "$RESPONSE" ]]; then
  echo "No places returned. Is the server up?"
  exit 1
fi
echo "Got $COUNT recommended places. Fetching SL travel times..."
echo ""

# ── SL travel time helper ────────────────────────────────────────────────────
sl_minutes() {
  local from_lat=$1 from_lon=$2 to_lat=$3 to_lon=$4
  local from to result
  from=$(python3 -c "print(f'{$from_lon}:{$from_lat}:WGS84[dd.ddddd]')")
  to=$(python3 -c "print(f'{$to_lon}:{$to_lat}:WGS84[dd.ddddd]')")
  result=$(curl -sf -H "User-Agent: MITTEN" \
    "$SL?type_origin=coord&name_origin=$(urlencode "$from")&type_destination=coord&name_destination=$(urlencode "$to")&calc_number_of_trips=3" \
    | jq -r '.journeys[0].tripDuration // empty')
  if [[ -z "$result" ]]; then echo "?"; else echo $(( result / 60 )); fi
}

# ── Table ────────────────────────────────────────────────────────────────────
printf "%-36s %11s %11s %11s %8s\n" "Place" "$NAME1" "$NAME2" "$NAME3" "Spread"
printf '%0.s─' {1..82}; echo ""

echo "$RESPONSE" | jq -r '.[] | "\(.displayName.text)\t\(.location.latitude)\t\(.location.longitude)"' | \
while IFS=$'\t' read -r place_name plat plon; do
  t1=$(sl_minutes "$LAT1" "$LON1" "$plat" "$plon")
  t2=$(sl_minutes "$LAT2" "$LON2" "$plat" "$plon")
  t3=$(sl_minutes "$LAT3" "$LON3" "$plat" "$plon")

  if [[ "$t1" =~ ^[0-9]+$ && "$t2" =~ ^[0-9]+$ && "$t3" =~ ^[0-9]+$ ]]; then
    max=$(( t1 > t2 ? t1 : t2 )); max=$(( max > t3 ? max : t3 ))
    min=$(( t1 < t2 ? t1 : t2 )); min=$(( min < t3 ? min : t3 ))
    spread="$(( max - min )) min"
  else
    spread="n/a"
  fi

  printf "%-36s %8s min %8s min %8s min %8s\n" \
    "${place_name:0:35}" "$t1" "$t2" "$t3" "$spread"
done

echo ""
echo "Spread = max − min travel time. A fair midpoint has spread ≤ ~5 min."
