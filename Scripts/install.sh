#!/bin/bash

set -euo pipefail

INSTALLER_URL="https://github.com/mtj0928/nest/releases/latest/download/install.sh"

echo "Warning: this installer URL is deprecated. Downloading the release installer instead." >&2
echo "Use this command next time: curl -fsSL $INSTALLER_URL | bash" >&2

# Finish downloading before running any of the release installer.
INSTALLER=$(curl -fsSL "$INSTALLER_URL")
exec bash -c "$INSTALLER"
