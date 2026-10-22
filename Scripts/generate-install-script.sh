#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ] || [ -z "$1" ]; then
  echo "Usage: $0 <release-tag> <artifact-bundle-zip> <output-script>" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CHECKSUM=$(shasum -a 256 "$2" | awk '{print $1}')
while IFS= read -r LINE || [ -n "$LINE" ]; do
  case "$LINE" in
    RELEASE_TAG=__RELEASE_TAG__)
      # Quote the tag as a shell value so it cannot become code in the installer.
      printf 'RELEASE_TAG=%q\n' "$1"
      ;;
    'CHECKSUM="__CHECKSUM__"')
      printf 'CHECKSUM="%s"\n' "$CHECKSUM"
      ;;
    *)
      printf '%s\n' "$LINE"
      ;;
  esac
done < "$SCRIPT_DIR/install.sh.template" > "$3"
chmod +x "$3"
