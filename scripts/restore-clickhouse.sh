#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=error-trap.sh
. "${SCRIPT_DIR}/error-trap.sh"
RESTORE_STEP="restore"

DATABASE="${DB_NAME:-default}"

echo "Starting ClickHouse restore: ${DB_HOST}:${DB_PORT}/${DATABASE}"

AUTH_ARGS=""
if [ -n "${DB_USER:-}" ]; then
  AUTH_ARGS="--user ${DB_USER}"
fi
if [ -n "${DB_PASSWORD:-}" ]; then
  AUTH_ARGS="${AUTH_ARGS} --password ${DB_PASSWORD}"
fi

# shellcheck source=clickhouse-archive.sh
. "${SCRIPT_DIR}/clickhouse-archive.sh"
S3_PATH="${CH_S3_PATH}"

CH_ERR="$(mktemp)"
if ! clickhouse-client \
  -h "${DB_HOST}" \
  --port "${DB_PORT}" \
  ${AUTH_ARGS} \
  --query "RESTORE DATABASE ${DATABASE} FROM ${S3_PATH}${CH_PASSWORD_SETTING}" 2> "$CH_ERR"; then
  cat "$CH_ERR" >&2
  if [ "$CH_ENCRYPTED" = "true" ] && grep -qiE "wrong password|password is required" "$CH_ERR"; then
    rm -f "$CH_ERR"
    echo "ERROR: Decryption failed" >&2
    exit 4
  fi
  rm -f "$CH_ERR"
  echo "ERROR: ClickHouse restore failed" >&2
  exit 5
fi
cat "$CH_ERR" >&2
rm -f "$CH_ERR"

if [ "$CH_ENCRYPTED" = "true" ]; then echo "ClickHouse archive: password-protected"; fi
echo "ClickHouse restore completed successfully"
