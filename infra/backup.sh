#!/usr/bin/env bash
# Copies the cosmos, accounts and history databases with SQLite's online
# backup (safe while the app is running), then keeps the last KEEP_DAYS days.
# Installed as /opt/lofi-infra/backup.sh; run by lofi-backup.service.
set -euo pipefail

DATA_DIR="${DATA_DIR:-/var/lib/lofi-eldritch-cosmos}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/lofi}"
KEEP_DAYS="${KEEP_DAYS:-14}"

target="$BACKUP_DIR/$(date -u +%Y-%m-%d)"
mkdir -p "$target"

for db in cosmos accounts history; do
  src="$DATA_DIR/$db.sqlite3"
  if [ -f "$src" ]; then
    sqlite3 "$src" ".backup '$target/$db.sqlite3'"
    sqlite3 "$target/$db.sqlite3" "PRAGMA integrity_check;" | grep -qx ok
  fi
done

find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +
echo "backed up to $target"
