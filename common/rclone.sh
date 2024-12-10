#!/usr/bin/env bash

if [ -z "$S3_ACCESS_KEY" ]; then
    echo "S3_ACCESS_KEY is not set"
    exit 1
fi

if [ -z "$S3_SECRET_KEY" ]; then
    echo "S3_SECRET_KEY is not set"
    exit 1
fi

if [ -z "$S3_ENDPOINT" ]; then
    echo "S3_ENDPOINT is not set"
    exit 1
fi

if [ -z "$S3_BUCKET_NAME" ]; then
    echo "S3_BUCKET_NAME is not set"
    exit 1
fi

RCLONE=$(which rclone)
echo "rclone executable: $RCLONE"

echo "configuring rclone"
"$RCLONE" config create --non-interactive cs2 s3 \
    "provider=Minio" \
    "access_key_id=$S3_ACCESS_KEY" \
    "secret_access_key=$S3_SECRET_KEY" \
    "endpoint=$S3_ENDPOINT" > /dev/null