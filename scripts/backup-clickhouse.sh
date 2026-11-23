#!/bin/bash
set -euo pipefail

DATABASE="${DB_NAME:-default}"

echo "Starting ClickHouse backup: ${DB_HOST}:${DB_PORT}/${DATABASE}"

AUTH_ARGS=""
if [ -n "${DB_USER:-}" ]; then
  AUTH_ARGS="--user ${DB_USER}"
fi
if [ -n "${DB_PASSWORD:-}" ]; then
  AUTH_ARGS="${AUTH_ARGS} --password ${DB_PASSWORD}"
fi

# ClickHouse can write backups directly to S3
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=clickhouse-archive.sh
. "${SCRIPT_DIR}/clickhouse-archive.sh"
S3_PATH="${CH_S3_PATH}"

clickhouse-client \
  -h "${DB_HOST}" \
  --port "${DB_PORT}" \
  ${AUTH_ARGS} \
  --query "BACKUP DATABASE ${DATABASE} TO ${S3_PATH}${CH_PASSWORD_SETTING}" || { echo "ERROR: ClickHouse backup failed" >&2; exit 2; }

if [ "$CH_ENCRYPTED" = "true" ]; then echo "ClickHouse archive: password-protected"; fi
echo "ClickHouse backup completed successfully"
