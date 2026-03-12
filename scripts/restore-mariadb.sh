#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_FILE="/tmp/restore.sql"

echo "Starting MariaDB restore: ${DB_HOST}:${DB_PORT}/${DB_NAME:-<all>}"

"${SCRIPT_DIR}/s3-download.sh" "${S3_BUCKET}" "${S3_KEY}" "/tmp/download.sql.gz" || { echo "ERROR: S3 download failed" >&2; exit 3; }

if [ -n "${ENCRYPTION_KEY:-}" ]; then
  "${SCRIPT_DIR}/decrypt.sh" "/tmp/download.sql.gz" "/tmp/decrypted.sql.gz" || { echo "ERROR: Decryption failed" >&2; exit 4; }
  gunzip -c /tmp/decrypted.sql.gz > "${DUMP_FILE}"
  rm -f /tmp/download.sql.gz /tmp/decrypted.sql.gz
else
  gunzip -c /tmp/download.sql.gz > "${DUMP_FILE}"
  rm -f /tmp/download.sql.gz
fi

mysql \
  -h "${DB_HOST}" \
  -P "${DB_PORT}" \
  -u "${DB_USER}" \
  -p"${DB_PASSWORD}" \
  ${DB_NAME:+"${DB_NAME}"} \
  < "${DUMP_FILE}" || { echo "ERROR: mysql restore failed" >&2; exit 5; }

rm -f "${DUMP_FILE}"
echo "MariaDB restore completed successfully"
