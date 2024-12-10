#!/usr/bin/env bash

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