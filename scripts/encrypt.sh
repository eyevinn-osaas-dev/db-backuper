#!/bin/bash
set -euo pipefail

INPUT_FILE="${1:?Usage: encrypt.sh <input_file> <output_file>}"
OUTPUT_FILE="${2:?Usage: encrypt.sh <input_file> <output_file>}"

openssl enc -aes-256-cbc -salt -pbkdf2 -pass env:ENCRYPTION_KEY -in "$INPUT_FILE" -out "$OUTPUT_FILE"
echo "Encrypted: $(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE") bytes"
