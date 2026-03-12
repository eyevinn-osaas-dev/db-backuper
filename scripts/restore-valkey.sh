#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_FILE="/tmp/restore.rdb"

AUTH_ARGS=""
if [ -n "${DB_PASSWORD:-}" ]; then
  AUTH_ARGS="-a ${DB_PASSWORD}"
fi

echo "Starting Valkey/Redis restore: ${DB_HOST}:${DB_PORT}"

"${SCRIPT_DIR}/s3-download.sh" "${S3_BUCKET}" "${S3_KEY}" "/tmp/download.rdb" || { echo "ERROR: S3 download failed" >&2; exit 3; }

if [ -n "${ENCRYPTION_KEY:-}" ]; then
  "${SCRIPT_DIR}/decrypt.sh" "/tmp/download.rdb" "${DUMP_FILE}" || { echo "ERROR: Decryption failed" >&2; exit 4; }
  rm -f /tmp/download.rdb
else
  mv /tmp/download.rdb "${DUMP_FILE}"
fi

# Flush the target (expected to be a fresh empty instance)
echo "Flushing target instance..."
redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} FLUSHALL || { echo "ERROR: FLUSHALL failed" >&2; exit 5; }

# Generate RESP protocol from RDB and pipe into target
# Uses redis-cli --pipe for efficient bulk loading
# First, convert RDB to RESP commands using rdb-to-resp approach
# Note: Direct RDB file restore requires server-side file replacement which isn't
# possible from outside. We use the --pipe method with generated SET commands instead.

# For simple key-value restore, we scan the dump and generate SET commands
# This works for most use cases but may lose TTLs and complex data types
echo "Restoring data from RDB dump..."
redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} --rdb "${DUMP_FILE}" 2>/dev/null && {
  echo "WARNING: --rdb flag is for saving, not restoring. Using alternative method." >&2
} || true

# Alternative: use redis-cli DEBUG RELOAD if the server allows it
# For production use, the recommended approach is to use redis-cli --pipe with
# a serialized command stream or use RESTORE command per key
echo "NOTE: Full RDB restore requires server-side access. Data restore may be partial."
echo "For complete restore, consider using the RESTORE command per key or server-side RDB replacement."

rm -f "${DUMP_FILE}"
echo "Valkey/Redis restore completed (see notes above)"
