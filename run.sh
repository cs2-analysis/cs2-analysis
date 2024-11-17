#!/usr/bin/env bash

set -e -o pipefail

MANIFEST_ID="${1:-$MANIFEST_ID}"
if [ -z "$MANIFEST_ID" ]; then
    echo "Usage: $0 <manifest_id>"
    exit 1
fi

# Load environment variables from .env file
# shellcheck disable=SC2046
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

# check if required environment variables are set
if [ -z "$APP_ID" ]; then
    echo "APP_ID is not set"
    exit 1
fi

if [ -z "$DEPOT_ID" ]; then
    echo "DEPOT_ID is not set"
    exit 1
fi

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

if [ -z "$METADATA_GIT_URL" ]; then
    echo "METADATA_GIT_URL is not set"
    exit 1
fi

if [ -z "$GIT_BRANCH" ]; then
    echo "GIT_BRANCH is not set"
    exit 1
fi

if [ -z "$GIT_EMAIL" ]; then
    echo "GIT_EMAIL is not set"
    exit 1
fi

if [ -z "$GIT_NAME" ]; then
    echo "GIT_NAME is not set"
    exit 1
fi

DEPOTDOWNLOADER=$(which DepotDownloader 2> /dev/null || which depotdownloader 2> /dev/null)
if [ -z "$DEPOTDOWNLOADER" ]; then
    echo "DepotDownloader not found in PATH"
    exit 1
fi

echo "DepotDownloader executable: $DEPOTDOWNLOADER"

RCLONE=$(which rclone 2> /dev/null)
if [ -z "$RCLONE" ]; then
    echo "rclone not found in PATH"
    exit 1
fi

echo "rclone executable: $RCLONE"

MANIFEST_GRABBER=$(which manifest-grabber 2> /dev/null)
if [ -z "$MANIFEST_GRABBER" ]; then
    echo "manifest-grabber not found in PATH"
    exit 1
fi

echo "manifest-grabber executable: $MANIFEST_GRABBER"

echo "configuring rclone"
"$RCLONE" config create --non-interactive cs2-dex s3 \
    "provider=Minio" \
    "access_key_id=$S3_ACCESS_KEY" \
    "secret_access_key=$S3_SECRET_KEY" \
    "endpoint=$S3_ENDPOINT" > /dev/null

echo "downloading depot"
"$DEPOTDOWNLOADER" -dir "depots/$MANIFEST_ID" \
    -app "$APP_ID" -depot "$DEPOT_ID" -manifest "$MANIFEST_ID" \
    -filelist <(echo 'regex:^.+\.(dll|exe|so)$')

# upload the files to the s3 bucket
rm -rf "staging"
mkdir -p -v "staging"

echo "Calculating checksums"
while read -r -d $'\0' file; do
    sha256=$(sha256sum "$file" | cut -d ' ' -f 1)
    
    # hardlink the file to the staging directory
    mkdir -p "staging/$sha256"
    ln "$file" "staging/$sha256/$(basename "$file")"
done < <(find "depots/$MANIFEST_ID" -type f -not -path '*/.*' -print0)

echo "Uploading files to S3"
"$RCLONE" copy "staging" "cs2-dex:$S3_BUCKET_NAME/$DEPOT_ID/" -v

echo "Downloading manifest"
mkdir -p -v "manifests"
manifest_path="manifests/$MANIFEST_ID.json"
"$MANIFEST_GRABBER" "$APP_ID" "$DEPOT_ID" "$MANIFEST_ID" > "$manifest_path"

echo "Uploading manifest to S3"
"$RCLONE" copy "$manifest_path" "cs2-dex:$S3_BUCKET_NAME/manfiests/$DEPOT_ID/" -v

echo "Cloning metadata repository"
rm -rf "metadata"
git clone "$METADATA_GIT_URL" "metadata"
if ! git -C "metadata" checkout "$GIT_BRANCH"; then
    git -C "metadata" checkout --orphan "$GIT_BRANCH"
    git -C "metadata" reset --hard
fi
git -C "metadata" config --local user.email "$GIT_EMAIL"
git -C "metadata" config --local user.name "$GIT_NAME"
mkdir -p -v "metadata/data"

echo "Updating metadata"
git_desc=""
nl=$'\n'
tab=$'\t'
creation_time=$(jq -r '.creation_time' < "$manifest_path")
while read -r -d $'\0' file; do
    sha256=$(sha256sum "$file" | cut -d ' ' -f 1)
    filename=$(basename "$file")
    size=$(stat --printf="%s" "$file")
    path="${file#depots/"$MANIFEST_ID"/}"

    # check if file already exists in metadata
    metadata_file="metadata/data/$path.json"
    if [ -f "$metadata_file" ]; then
        old_sha256=$(jq -r '.sha256' < "$metadata_file")
        if [ "$sha256" = "$old_sha256" ]; then
            # echo "$path unchanged"
            continue
        fi

        old_size=$(jq -r '.size' < "$metadata_file")
        delta_size=$((size - old_size))
        if [ $delta_size -lt 0 ]; then
            git_desc+="M$tab$path$tab$delta_size$nl"
        elif [ $delta_size -gt 0 ]; then
            git_desc+="M$tab$path$tab+$delta_size$nl"
        else
            git_desc+="M$tab$path$nl"
        fi
        echo "$path updated"
    else
        git_desc+="A$tab$path$nl"
        echo "$path added"
    fi

    mkdir -p -v "$(dirname "$metadata_file")"
    jq -n \
        --arg filename "$filename" \
        --arg path "$path" \
        --arg size "$size" \
        --arg sha256 "$sha256" \
        --arg manifest "$MANIFEST_ID" \
        --arg updated "$creation_time" \
        '{filename: $filename, path: $path, size: $size, sha256: $sha256, manifest: $manifest, updated: $updated}' \
        > "$metadata_file"
done < <(find "depots/$MANIFEST_ID" -type f -not -path '*/.*' -print0)

# detect deleted files
while read -r -d $'\0' file; do
    path="$(jq -r '.path' < "$file")"
    if [ ! -f "depots/$MANIFEST_ID/$path" ]; then
        # check if file already marked as deleted
        if jq -e '.deleted' < "$file" > /dev/null; then
            continue
        fi

        jq --arg manifest "$MANIFEST_ID" --arg updated "$creation_time" \
            'del(.size, .sha256) | .manifest = $manifest | .updated = $updated | .deleted = true' \
            < "$file" > "$file.tmp"
        mv "$file.tmp" "$file"

        git_desc+="D$tab$path$nl"
        echo "$path deleted"
    fi
done < <(find "metadata/data" -type f -not -path '*/.*' -print0)

if [ -n "$git_desc" ]; then
    git -C "metadata" add .
    git_date=$(date -d "@$creation_time")
    GIT_COMMITTER_DATE="$git_date" GIT_AUTHOR_DATE="$git_date" \
        git -C "metadata" commit -m "$MANIFEST_ID" -m "$git_desc"
    git -C "metadata" push origin "$GIT_BRANCH"
fi