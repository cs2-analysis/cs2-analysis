#!/usr/bin/env bash

set -e -o pipefail

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set"
    exit 1
fi

while IFS= read -r line; do
    # create github action body using jq
    data=$(jq -n -c --arg manifestId "$line" '{ref: "master", inputs: {depotId: "2347771", manifestId: $manifestId, gitBranch: "windows"}}')

    echo "Triggering github action for manifest $line"

    # # trigger github action
    curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/cs2-analysis/cs2-dex/actions/workflows/update.yml/dispatches \
        -d "$data"
    
    echo "$line" >> triggered.txt
    sleep 60
done < manifests.txt
