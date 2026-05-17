#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_DIR="$REPO_DIR/build/R4.5.0-arm64-macos/00LOCK-temp"

cd "$REPO_DIR"

if [[ -d "$LOCK_DIR" ]]; then
  echo "Removing stale lock: $LOCK_DIR"
  rm -rf "$LOCK_DIR"
fi

echo "Installing jamovi module via jmvtools..."
Rscript -e "jmvtools::install()"
