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
S3_PATH="S3('${S3_ENDPOINT}/${S3_BUCKET}/${S3_KEY}', '${S3_ACCESS_KEY}', '${S3_SECRET_KEY}')"

clickhouse-client \
  -h "${DB_HOST}" \
  --port "${DB_PORT}" \
  ${AUTH_ARGS} \
  --query "BACKUP DATABASE ${DATABASE} TO ${S3_PATH}" || { echo "ERROR: ClickHouse backup failed" >&2; exit 2; }

echo "ClickHouse backup completed successfully"
