#!/bin/bash
set -euo pipefail

# Security & Bug Fix: Enforce argument validation
if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Error: Missing required argument 'APP'." >&2
  echo "Usage: $0 <app-name>" >&2
  exit 1
fi

APP="$1"
ROOT="$(pwd)"

if [ ! -d "$APP" ]; then
  echo "Error: Directory '$APP' does not exist." >&2
  exit 1
fi

# Ensure returning to ROOT directory upon script completion or failure
cleanup() {
  cd "$ROOT"
}
trap cleanup EXIT

echo "=== Building application: ${APP} ==="
cd "$APP"

./mvnw clean
./mvnw versions:set -DremoveSnapshot

# Extract version safely
APP_VERSION=$(./mvnw -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec | tr -d '\r\n')

if [ -z "$APP_VERSION" ]; then
  echo "Error: Failed to determine application version." >&2
  exit 1
fi

./mvnw package
./mvnw versions:set -DnextSnapshot

# Safely handle git operations if in a git repository
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add pom.xml
  git commit -m "cicd: bump version ${APP}:${APP_VERSION}" || echo "Git commit skipped or no changes."
fi

cd "$ROOT"
echo "=== Building Docker image for ${APP} with tag ${APP_VERSION} ==="
TAG="$APP_VERSION" docker compose build --no-cache "$APP"

echo "=== Build finished for ${APP} ==="
docker images "dio/${APP}"
