#!/bin/bash

REPO="mtj0928/nest"
ASSET_NAME="nest-macos.artifactbundle.zip"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

# Fetch release info
RELEASE_INFO=$(curl -s $API_URL)
ASSET_URL=$(echo "$RELEASE_INFO" | grep "browser_download_url.*$ASSET_NAME" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=$(echo "$RELEASE_INFO" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Download zip file
if [ -n "$ASSET_URL" ]; then
    curl -sL -o $ASSET_NAME $ASSET_URL
    unzip -qo $ASSET_NAME -d extracted_files
    rm $ASSET_NAME
    ./extracted_files/nest.artifactbundle/nest-$VERSION-macos/bin/nest install mtj0928/nest > /dev/null
    rm -rf extracted_files
    echo "🪺 nest was installed at ~/.nest/bin"
    echo "🪺 Please add it to \$PATH"
else
    echo "Failed to install"
    exit 1
fi

