#!/bin/bash
set -euo pipefail

LOCAL_FILE="${1:?Usage: s3-upload.sh <local_file> <bucket> <key>}"
BUCKET="${2:?Usage: s3-upload.sh <local_file> <bucket> <key>}"
KEY="${3:?Usage: s3-upload.sh <local_file> <bucket> <key>}"

echo "Uploading to s3://${BUCKET}/${KEY}..."
mc cp "$LOCAL_FILE" "backup/${BUCKET}/${KEY}"
echo "Upload complete"
