#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Formatting R code with air..."
air format "$REPO_DIR/R"

echo "Formatting client code with prettier..."
cd "$REPO_DIR/client"
npm run format
