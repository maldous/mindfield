#!/usr/bin/env sh

set -e

echo "BACKUP_DIR=${BACKUP_DIR}, INTERVAL=${BACKUP_INTERVAL}s, RETENTION=${RETENTION_DAYS}d"

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleeping for ${BACKUP_INTERVAL}s"
  sleep "$BACKUP_INTERVAL"

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  FILE_TPL='${BACKUP_DIR}/backup_${TIMESTAMP}.sql'
  BACKUP_FILE=$(echo "$FILE_TPL" | envsubst)

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating dump $BACKUP_FILE"
  pg_dumpall > "$BACKUP_FILE"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removing backups older than ${RETENTION_DAYS} days"
  find "$BACKUP_DIR" -name '*.sql' -mtime +"$RETENTION_DAYS" -exec rm {} \;
done
