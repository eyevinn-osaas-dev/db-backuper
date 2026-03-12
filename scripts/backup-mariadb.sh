#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DUMP_FILE="/tmp/backup.sql.gz"

echo "Starting MariaDB backup: ${DB_HOST}:${DB_PORT}/${DB_NAME:-<all>}"

mysqldump \
  -h "${DB_HOST}" \
  -P "${DB_PORT}" \
  -u "${DB_USER}" \
  -p"${DB_PASSWORD}" \
  ${DB_NAME:+--databases "${DB_NAME}"} \
  ${DB_NAME:-"--all-databases"} \
  --single-transaction \
  | gzip > "${DUMP_FILE}" || { echo "ERROR: mysqldump failed" >&2; exit 2; }

DUMP_SIZE=$(stat -c%s "${DUMP_FILE}" 2>/dev/null || stat -f%z "${DUMP_FILE}")
echo "Dump completed: ${DUMP_SIZE} bytes (compressed)"

UPLOAD_FILE="${DUMP_FILE}"
if [ -n "${ENCRYPTION_KEY:-}" ]; then
  ENCRYPTED_FILE="/tmp/backup.sql.gz.enc"
  "${SCRIPT_DIR}/encrypt.sh" "${DUMP_FILE}" "${ENCRYPTED_FILE}"
  UPLOAD_FILE="${ENCRYPTED_FILE}"
fi

"${SCRIPT_DIR}/s3-upload.sh" "${UPLOAD_FILE}" "${S3_BUCKET}" "${S3_KEY}" || { echo "ERROR: S3 upload failed" >&2; exit 3; }

rm -f /tmp/backup.sql.gz /tmp/backup.sql.gz.enc
echo "MariaDB backup completed successfully"
