#!/bin/bash

REPO="mtj0928/nest"
ASSET_NAME="nest-macos.artifactbundle.zip"
ASSET_URL="https://github.com/$REPO/releases/latest/download/$ASSET_NAME"

# Download zip file
curl -sL -o $ASSET_NAME $ASSET_URL
unzip -qo $ASSET_NAME -d extracted_files
rm $ASSET_NAME

VERSION=$(ls ./extracted_files/nest.artifactbundle | sed -n 's/^nest-\([^-]*\)-macos$/\1/p' | head -n 1)
if [ -z "$VERSION" ]; then
  echo "Version not found in the directory."
  exit 1
fi

./extracted_files/nest.artifactbundle/nest-$VERSION-macos/bin/nest install mtj0928/nest > /dev/null
rm -rf extracted_files
echo "🪺 nest was installed at ~/.nest/bin"
echo "🪺 Please add it to \$PATH"
