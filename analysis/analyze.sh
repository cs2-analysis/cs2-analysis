#!/usr/bin/env bash

set -e -o pipefail

FILE_PATH="${1:-$FILE_PATH}"
if [ -z "$FILE_PATH" ]; then
    echo "Usage: $0 <file_path>"
    exit 1
fi

# Load environment variables from .env file
# shellcheck disable=SC2046
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

source ../common/rclone.sh

rm -rf "staging"
mkdir -p -v "staging"

echo downloading file
"$RCLONE" copy "cs2:$S3_BUCKET_NAME" "staging" -v --include "$FILE_PATH"

if [ ! -f "staging/$FILE_PATH" ]; then
    echo "Failed to download file"
    exit 1
fi

script -q -e -f -c "./analyze.py \"staging/$FILE_PATH\"" /dev/null

# compress all .BinExport files
find "staging" -type f -name "*.BinExport" -exec gzip -9 -v "{}" \; -exec mv -v "{}.gz" "{}" \;

"$RCLONE" copy "staging" "cs2:$S3_BUCKET_NAME" -v --include "*.i64" --ignore-size

# why can't we just --metadata-set without --metadata? come on rclone...
"$RCLONE" copy "staging" "cs2:$S3_BUCKET_NAME" -v --include "*.BinExport" \
  --metadata --metadata-mapper "./rclone_content_encoding.py gzip" --ignore-size