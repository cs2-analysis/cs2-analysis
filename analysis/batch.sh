#!/usr/bin/env bash

set -e -o pipefail

# Load environment variables from .env file
# shellcheck disable=SC2046
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set"
    exit 1
fi

if [ -z "$DEPOT_ID" ]; then
    echo "DEPOT_ID is not set"
    exit 1
fi

if [ -z "$GIT_BRANCH" ]; then
    echo "GIT_BRANCH is not set"
    exit 1
fi

while IFS= read -r line; do
    # create github action body using jq
    data=$(jq -n -c --arg depotId "$DEPOT_ID" --arg manifestId "$line" --arg gitBranch "$GIT_BRANCH" \
      '{ref: "master", inputs: {depotId: $depotId, manifestId: $manifestId, gitBranch: $gitBranch}}')

    echo "Triggering github action for manifest $line"

    # # trigger github action
    curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/cs2-analysis/cs2-analysis/actions/workflows/analyze.yml/dispatches \
        -d "$data"
    
    echo "$line" >> triggered.txt
    sleep 200
done < manifests.txt
