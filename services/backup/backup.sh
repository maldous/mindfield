#!/usr/bin/env sh
set -euo pipefail

mkdir -p "$BACKUP_DIR"

TS=$(date +%Y%m%d_%H%M%S)
DB_NAME=$(printf '%s\n' "$DATABASE_URL" | sed -E 's#.*/([^/?]+).*#\1#')
OUT_FILE="${BACKUP_DIR}/${DB_NAME}_${TS}.sql"

echo "[$(date '+%F %T')] Dumping ${DB_NAME} → ${OUT_FILE}.${COMPRESS_CMD:+$COMPRESS_CMD}"
pg_dump --dbname="$DATABASE_URL" --format=custom | ${COMPRESS_CMD:-cat} > "${OUT_FILE}${COMPRESS_CMD:+.$(basename $COMPRESS_CMD)}"

echo "[$(date '+%F %T')] Removing dumps older than ${RETENTION_DAYS} day(s)"
find "$BACKUP_DIR" -type f -name '*.sql*' -mtime +"$RETENTION_DAYS" -delete

