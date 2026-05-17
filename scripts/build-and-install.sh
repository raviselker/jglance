#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_DIR/client"
echo "Building client bundle..."
npm run build

cd "$REPO_DIR"
echo "Installing jamovi module..."
"$REPO_DIR/scripts/install-module.sh"
