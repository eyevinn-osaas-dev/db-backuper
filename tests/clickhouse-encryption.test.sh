#!/bin/bash
# ClickHouse backup/restore with ENCRYPTION_KEY: derived per-archive password, key never sent.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="tenant-key-SECRET-xyz"
PASS=0
FAILN=0
ok() { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad() { FAILN=$((FAILN + 1)); echo "  FAIL $1"; }
expect() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

new_env() {
  WORK=$(mktemp -d)
  mkdir -p "$WORK/bin"
  cp "$ROOT"/scripts/*.sh "$WORK/"
  cat > "$WORK/bin/clickhouse-client" <<'STUB'
#!/bin/bash
while [ $# -gt 0 ]; do
  if [ "$1" = "--query" ]; then echo "$2" >> "$STUB_QUERY"; fi
  shift
done
if [ -n "${STUB_FAIL_MSG:-}" ]; then echo "$STUB_FAIL_MSG" >&2; exit 1; fi
exit 0
STUB
  chmod +x "$WORK/bin/clickhouse-client"
  export STUB_QUERY="$WORK/query"
  : > "$STUB_QUERY"
  OUT="$WORK/out"
}

# run <script> [VAR=value ...]
run() {
  local s="$1"; shift
  env -u ENCRYPTION_KEY -u STUB_FAIL_MSG PATH="$WORK/bin:$PATH" STUB_QUERY="$STUB_QUERY" \
    DB_HOST=h DB_PORT=9000 DB_NAME=d S3_ENDPOINT=http://s3 S3_BUCKET=b S3_KEY=pfx/backup \
    S3_ACCESS_KEY=ak S3_SECRET_KEY=sk "$@" bash "$WORK/$s" > "$OUT" 2>&1
  RC=$?
}

pw_of() { sed -n "s/.*SETTINGS password = '\([0-9a-f]*\)'.*/\1/p" "$STUB_QUERY" | head -1; }
no_key() { ! grep -qF "$KEY" "$OUT" && ! grep -qF "$KEY" "$STUB_QUERY"; }
no_line() { ! grep -q 'password-protected' "$OUT"; }

echo "backup, key unset: byte-identical query, no encrypted line"
new_env; run backup-clickhouse.sh
expect "exit 0" test "$RC" -eq 0
expect "query unchanged" grep -qxF "BACKUP DATABASE d TO S3('http://s3/b/pfx/backup', 'ak', 'sk')" "$STUB_QUERY"
expect "no encrypted line" no_line

echo "restore, key unset: byte-identical query, no encrypted line"
new_env; run restore-clickhouse.sh
expect "exit 0" test "$RC" -eq 0
expect "query unchanged" grep -qxF "RESTORE DATABASE d FROM S3('http://s3/b/pfx/backup', 'ak', 'sk')" "$STUB_QUERY"
expect "no encrypted line" no_line

echo "backup, key set: .zip object, derived password, encrypted line, key never exposed"
new_env; run backup-clickhouse.sh ENCRYPTION_KEY="$KEY"
BPW=$(pw_of)
expect "exit 0" test "$RC" -eq 0
expect "object key gets .zip" grep -qF "http://s3/b/pfx/backup.zip" "$STUB_QUERY"
expect "password is 64 hex chars" test "${#BPW}" -eq 64
expect "encrypted line printed" grep -qxF "ClickHouse archive: password-protected" "$OUT"
expect "raw key not in query or log" no_key
EXPECTED=$(printf '%s' "pfx/backup.zip" | openssl dgst -sha256 -hmac "$KEY" | awk '{print $NF}')
expect "password is HMAC(key, object key)" test "$BPW" = "$EXPECTED"

echo "restore, key set: same password (round trip)"
new_env; run restore-clickhouse.sh ENCRYPTION_KEY="$KEY"
RPW=$(pw_of)
expect "exit 0" test "$RC" -eq 0
expect "restore derives backup password" test "$RPW" = "$BPW"
expect "encrypted line printed" grep -qxF "ClickHouse archive: password-protected" "$OUT"
expect "raw key not in query or log" no_key

echo "restore with an object key already ending .zip keeps it"
new_env; run restore-clickhouse.sh ENCRYPTION_KEY="$KEY" S3_KEY=pfx/backup.zip
expect "same password" test "$(pw_of)" = "$BPW"

echo "restore, key set, wrong password: exit 4, Decryption failed"
new_env; run restore-clickhouse.sh ENCRYPTION_KEY="$KEY" STUB_FAIL_MSG="Code: 643. Wrong password."
expect "exit 4" test "$RC" -eq 4
expect "ERROR line" grep -qxF "ERROR: Decryption failed" "$OUT"
expect "no encrypted line" no_line

echo "restore, key set, other failure: exit 5"
new_env; run restore-clickhouse.sh ENCRYPTION_KEY="$KEY" STUB_FAIL_MSG="Code: 210. connection refused"
expect "exit 5" test "$RC" -eq 5
expect "ERROR line" grep -qxF "ERROR: ClickHouse restore failed" "$OUT"

echo
echo "passed=$PASS failed=$FAILN"
[ "$FAILN" -eq 0 ]
