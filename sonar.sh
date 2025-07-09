#!/usr/bin/env bash
set -euo pipefail

for ((p=1;;p++)); do
  r=$(curl -s -u admin:admin "http://localhost:3016/api/issues/search?branch=main&ps=500&p=$p")
  jq -e '.issues|length==0' <<<"$r" && break
  printf '%s\n' "$r"
done | jq -s 'map(.issues)|add' > sonar.json

echo -e "\n--\n"
