#!/bin/bash

VERSION_STRING="$1"

mkdir -p nest.artifactbundle/nest-$VERSION_STRING-macos/bin

sed "s/__VERSION__/$VERSION_STRING/g" ./Scripts/info.json > "nest.artifactbundle/info.json"

cp -f ".build/release/nest" "nest.artifactbundle/nest-$VERSION_STRING-macos/bin"

zip -yr - "nest.artifactbundle" > "./nest-macos.artifactbundle.zip"
