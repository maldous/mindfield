#!/bin/bash
set -e

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql"

echo "Starting database backup..."

mkdir -p "${BACKUP_DIR}"

pg_dumpall -h postgres -U mindfield > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Backup completed: ${BACKUP_FILE}"
    
    gzip "${BACKUP_FILE}"
    echo "Backup compressed: ${BACKUP_FILE}.gz"
    
    echo "Cleaning up old backups..."
    find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +14 -delete
    
    echo "Current backups:"
    ls -lh "${BACKUP_DIR}"/*.sql.gz 2>/dev/null || echo "No backups found"
    
    if [ "$(date +%u)" -eq 1 ]; then
        echo "Testing backup integrity..."
        if gunzip -t "${BACKUP_FILE}.gz"; then
            echo "Backup integrity check passed"
        else
            echo "Backup integrity check failed"
            exit 1
        fi
    fi
else
    echo "Backup failed"
    exit 1
fi

echo "Backup process completed successfully"
