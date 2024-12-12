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

if [ -z "$DEPOT_ID" ]; then
    echo "DEPOT_ID is not set"
    exit 1
fi

source ../common/git.sh

echo "Cloning metadata repository"
rm -rf "metadata"
git clone "$METADATA_GIT_URL" "metadata" || true
git -C metadata checkout "$GIT_BRANCH"

GIT_COMMIT=$(git -C metadata log --pretty=format:"%H" --no-patch --grep="^$MANIFEST_ID$" | head -n 1)

echo "Checking out commit $GIT_COMMIT"
file_list=$(git -C metadata diff-tree --no-commit-id --name-only -r --root "$GIT_COMMIT")
git -c advice.detachedHead=false -C metadata checkout "$GIT_COMMIT"

paths=""
while read -r -d $'\n' file; do
    file="metadata/$file"

    # skip deleted files
    if jq -e '.deleted' < "$file" > /dev/null; then
        continue
    fi

    hash=$(jq -r '.sha256' < "$file")
    filename=$(jq -r '.filename' < "$file")

    paths+="$DEPOT_ID/$hash/$filename"$'\n'
done < <(echo "$file_list")

echo "files=$(echo -n "$paths" | jq -RncM '[inputs]')" >> "$GITHUB_OUTPUT"