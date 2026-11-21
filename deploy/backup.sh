#!/usr/bin/env bash
# Nightly MySQL backup for Brunchy (scheduled by server-setup.sh). Keeps 14 days in /var/backups/brunchy.
# Run by hand any time:  bash /opt/brunchy/deploy/backup.sh
# Restore (overwrites the database!):
#   gunzip -c /var/backups/brunchy/brunchy-YYYY-MM-DD_HHMM.sql.gz | \
#     docker compose -f /opt/brunchy/deploy/docker-compose.prod.yml exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" brunchy'
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR=/var/backups/brunchy
KEEP_DAYS=14
mkdir -p "$BACKUP_DIR"

file="$BACKUP_DIR/brunchy-$(date -u +%F_%H%M).sql.gz"
docker compose -f "$DEPLOY_DIR/docker-compose.prod.yml" exec -T mysql \
  sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --no-tablespaces brunchy' \
  | gzip > "$file.tmp"
mv "$file.tmp" "$file"
find "$BACKUP_DIR" -name 'brunchy-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "$(date -u +%FT%TZ) backup ok: $file ($(du -h "$file" | cut -f1))"
