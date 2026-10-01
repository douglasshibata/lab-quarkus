#!/bin/bash
set -euo pipefail

# Security & Bug Fix: Enforce required positional arguments
if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "Error: Invalid arguments." >&2
  echo "Usage: $0 <app-name> <green-deploy-tag>" >&2
  exit 1
fi

APP="$1"
GREEN_CONTAINER_DEPLOY_TAG="$2"

echo "=== Starting Blue-Green Deployment for ${APP} (Tag: ${GREEN_CONTAINER_DEPLOY_TAG}) ==="

# Get existing blue container IDs safely
BLUE_CONTAINERS=$(docker ps -q -f "name=${APP}" || true)
if [ -n "$BLUE_CONTAINERS" ]; then
  BLUE_CONTAINERS_SCALE=$(echo "$BLUE_CONTAINERS" | wc -w | xargs)
else
  BLUE_CONTAINERS_SCALE=0
fi

# Calculate green scale factor
GREEN_CONTAINERS_SCALE=$((BLUE_CONTAINERS_SCALE * 2))
if [ "$BLUE_CONTAINERS_SCALE" -eq 0 ]; then
  GREEN_CONTAINERS_SCALE=1
fi

echo "Blue container count: ${BLUE_CONTAINERS_SCALE}"
echo "Deploying Green scale target: ${GREEN_CONTAINERS_SCALE}"

TAG="$GREEN_CONTAINER_DEPLOY_TAG" docker compose up -d "$APP" --scale "${APP}=${GREEN_CONTAINERS_SCALE}" --no-recreate --no-build

# Bug Fix: Prevent infinite loop by adding timeout for health check polling
MAX_TIMEOUT_SECONDS=120
ELAPSED=0
POLL_INTERVAL=2

until [ "$(docker ps -q -f "name=${APP}" -f "health=healthy" | wc -l | xargs)" -ge "$GREEN_CONTAINERS_SCALE" ]; do
  if [ "$ELAPSED" -ge "$MAX_TIMEOUT_SECONDS" ]; then
    echo "Error: Timed out waiting for green deployment containers to become healthy." >&2
    exit 1
  fi
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
  echo "Waiting for healthy containers (${ELAPSED}s / ${MAX_TIMEOUT_SECONDS}s)..."
done

echo "Green deployment healthy!"

# Bug Fix: Correctly pass container IDs to docker kill via xargs instead of quoted multi-line string
if [ "$BLUE_CONTAINERS_SCALE" -gt 0 ] && [ -n "$BLUE_CONTAINERS" ]; then
  echo "Terminating old blue containers..."
  echo "$BLUE_CONTAINERS" | xargs -r docker kill --signal=SIGTERM
fi

echo "=== Blue-Green Deployment completed successfully for ${APP} ==="
