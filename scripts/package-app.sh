#!/usr/bin/env bash
# Builds dist/<version>.tar.gz with production node_modules bundled (instances need no npm).
set -euo pipefail
VERSION="${1:?usage: package-app.sh <version>}"
cd "$(dirname "$0")/../app"
if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi
mkdir -p ../dist
tar -czf "../dist/${VERSION}.tar.gz" server.js package.json src node_modules
echo "Built dist/${VERSION}.tar.gz"
