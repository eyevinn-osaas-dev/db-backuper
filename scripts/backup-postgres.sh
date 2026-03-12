#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_FILE="/tmp/backup.dump"

echo "Starting PostgreSQL backup: ${DB_HOST}:${DB_PORT}/${DB_NAME:-<all>}"

export PGPASSWORD="${DB_PASSWORD}"

pg_dump \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  ${DB_NAME:+-d "${DB_NAME}"} \
  -Fc \
  -f "${DUMP_FILE}" || { echo "ERROR: pg_dump failed" >&2; exit 2; }

DUMP_SIZE=$(stat -c%s "${DUMP_FILE}" 2>/dev/null || stat -f%z "${DUMP_FILE}")
echo "Dump completed: ${DUMP_SIZE} bytes"

UPLOAD_FILE="${DUMP_FILE}"
if [ -n "${ENCRYPTION_KEY:-}" ]; then
  ENCRYPTED_FILE="/tmp/backup.dump.enc"
  "${SCRIPT_DIR}/encrypt.sh" "${DUMP_FILE}" "${ENCRYPTED_FILE}"
  UPLOAD_FILE="${ENCRYPTED_FILE}"
fi

"${SCRIPT_DIR}/s3-upload.sh" "${UPLOAD_FILE}" "${S3_BUCKET}" "${S3_KEY}" || { echo "ERROR: S3 upload failed" >&2; exit 3; }

rm -f /tmp/backup.dump /tmp/backup.dump.enc
echo "PostgreSQL backup completed successfully"
