#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_FILE="/tmp/dump.rdb"

AUTH_ARGS=""
if [ -n "${DB_PASSWORD:-}" ]; then
  AUTH_ARGS="-a ${DB_PASSWORD}"
fi

echo "Starting Valkey/Redis backup: ${DB_HOST}:${DB_PORT}"

# Trigger BGSAVE
redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} BGSAVE || { echo "ERROR: BGSAVE failed" >&2; exit 2; }

# Wait for BGSAVE to complete (poll LASTSAVE, max 120s)
LAST_SAVE=$(redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} LASTSAVE)
echo "Waiting for BGSAVE to complete..."
for i in $(seq 1 60); do
  sleep 2
  CURRENT_SAVE=$(redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} LASTSAVE)
  if [ "$CURRENT_SAVE" != "$LAST_SAVE" ]; then
    echo "BGSAVE completed"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: BGSAVE did not complete within 120 seconds" >&2
    exit 2
  fi
done

# Download RDB file
redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${AUTH_ARGS} --rdb "${DUMP_FILE}" || { echo "ERROR: RDB download failed" >&2; exit 2; }

DUMP_SIZE=$(stat -c%s "${DUMP_FILE}" 2>/dev/null || stat -f%z "${DUMP_FILE}")
echo "RDB dump completed: ${DUMP_SIZE} bytes"

UPLOAD_FILE="${DUMP_FILE}"
if [ -n "${ENCRYPTION_KEY:-}" ]; then
  ENCRYPTED_FILE="/tmp/dump.rdb.enc"
  "${SCRIPT_DIR}/encrypt.sh" "${DUMP_FILE}" "${ENCRYPTED_FILE}"
  UPLOAD_FILE="${ENCRYPTED_FILE}"
fi

"${SCRIPT_DIR}/s3-upload.sh" "${UPLOAD_FILE}" "${S3_BUCKET}" "${S3_KEY}" || { echo "ERROR: S3 upload failed" >&2; exit 3; }

rm -f /tmp/dump.rdb /tmp/dump.rdb.enc
echo "Valkey/Redis backup completed successfully"
