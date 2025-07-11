#!/usr/bin/env sh
set -euo pipefail

mkdir -p "$BACKUP_DIR"

while true; do

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleeping for ${BACKUP_INTERVAL}s"
  sleep "$BACKUP_INTERVAL"

  TS=$(date +%Y%m%d_%H%M%S)
  DB_NAME=$(printf '%s\n' "$DATABASE_URL" | sed -E 's#.*/([^/?]+).*#\1#')
  OUT_FILE="${BACKUP_DIR}/${DB_NAME}_${TS}.sql"

  echo "[$(date '+%F %T')] Dumping ${DB_NAME} → ${OUT_FILE}.gz"
  pg_dump --dbname="$DATABASE_URL" --format=custom | gzip > "${OUT_FILE}.gz"

  echo "[$(date '+%F %T')] Removing dumps older than ${RETENTION_DAYS} day(s)"
  find "$BACKUP_DIR" -type f -name '*.sql.gz' -mtime +"$RETENTION_DAYS" -delete

done
