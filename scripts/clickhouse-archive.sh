#!/bin/bash
# Sourced by backup-clickhouse.sh and restore-clickhouse.sh.
#
# With ENCRYPTION_KEY set, the archive is a password-protected .zip. The password is
# HMAC-SHA256(ENCRYPTION_KEY, <archive object key>) in hex, so it opens that one archive only.
# The tenant key itself is never sent to ClickHouse (ADR-0006 amendment 2026-11-23).
# ClickHouse picks the archive format from the file extension, hence the .zip suffix.

CH_OBJECT_KEY="${S3_KEY}"
CH_PASSWORD_SETTING=""
CH_ENCRYPTED=false

if [ -n "${ENCRYPTION_KEY:-}" ]; then
  case "$CH_OBJECT_KEY" in
    *.zip) ;;
    *) CH_OBJECT_KEY="${CH_OBJECT_KEY}.zip" ;;
  esac
  CH_DERIVED="$(printf '%s' "$CH_OBJECT_KEY" | openssl dgst -sha256 -hmac "$ENCRYPTION_KEY" | awk '{print $NF}')"
  if [ -z "$CH_DERIVED" ]; then
    echo "ERROR: could not derive the ClickHouse archive password" >&2
    exit 4
  fi
  CH_PASSWORD_SETTING=" SETTINGS password = '${CH_DERIVED}'"
  CH_ENCRYPTED=true
fi

CH_S3_PATH="S3('${S3_ENDPOINT}/${S3_BUCKET}/${CH_OBJECT_KEY}', '${S3_ACCESS_KEY}', '${S3_SECRET_KEY}')"
