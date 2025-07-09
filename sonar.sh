#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <SONAR_TOKEN>"
  exit 1
fi

TOKEN="$1"
BASE_URL="http://localhost:3016"
BRANCH="main"
PAGE_SIZE=500
OUTPUT="sonar.json"

for ((p=1;;p++)); do
  resp=$(curl -s -u "${TOKEN}": \
    "${BASE_URL}/api/issues/search?branch=${BRANCH}&ps=${PAGE_SIZE}&p=${p}")
  [ "$(jq '.issues|length' <<< "$resp")" -eq 0 ] && break
  printf '%s\n' "$resp"
done | jq -s 'map(.issues) | add' > "$OUTPUT"
