#!/usr/bin/env bash

if [ -z "$STEAM_USERNAME" ]; then
    echo "STEAM_USERNAME is not set"
    exit 1
fi

if [ -z "$STEAM_PASSWORD" ]; then
    echo "STEAM_PASSWORD is not set"
    exit 1
fi

DEPOTDOWNLOADER=$(which DepotDownloader 2> /dev/null || which depotdownloader)
echo "DepotDownloader executable: $DEPOTDOWNLOADER"