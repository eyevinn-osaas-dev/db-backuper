#!/bin/bash
set -euo pipefail

BUCKET="${1:?Usage: s3-download.sh <bucket> <key> <local_file>}"
KEY="${2:?Usage: s3-download.sh <bucket> <key> <local_file>}"
LOCAL_FILE="${3:?Usage: s3-download.sh <bucket> <key> <local_file>}"

echo "Downloading s3://${BUCKET}/${KEY}..."
mc cp "backup/${BUCKET}/${KEY}" "$LOCAL_FILE"
echo "Download complete: $(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE") bytes"
