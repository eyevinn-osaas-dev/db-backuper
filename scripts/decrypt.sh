#!/bin/bash
set -euo pipefail

INPUT_FILE="${1:?Usage: decrypt.sh <input_file> <output_file>}"
OUTPUT_FILE="${2:?Usage: decrypt.sh <input_file> <output_file>}"

openssl enc -d -aes-256-cbc -pbkdf2 -pass env:ENCRYPTION_KEY -in "$INPUT_FILE" -out "$OUTPUT_FILE"
echo "Decrypted: $(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE") bytes"
