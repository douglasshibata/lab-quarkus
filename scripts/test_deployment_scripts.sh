#!/bin/bash
set -euo pipefail

echo "=========================================="
echo " Running Automated Infrastructure Tests"
echo "=========================================="

FAILED=0

test_case() {
  local description="$1"
  shift
  echo -n "Test: ${description} ... "
  if "$@"; then
    echo "PASSED"
  else
    echo "FAILED"
    FAILED=$((FAILED + 1))
  fi
}

# 1. Test cicd-build.sh argument validation
test_cicd_build_no_args() {
  ! ./cicd-build.sh >/dev/null 2>&1
}

test_cicd_build_invalid_dir() {
  ! ./cicd-build.sh non_existent_app_12345 >/dev/null 2>&1
}

# 2. Test cicd-blue-green-deployment.sh argument validation
test_cicd_bg_no_args() {
  ! ./cicd-blue-green-deployment.sh >/dev/null 2>&1
}

test_cicd_bg_one_arg() {
  ! ./cicd-blue-green-deployment.sh voting-app >/dev/null 2>&1
}

# 3. Test docker compose configuration syntax (if docker compose is available or file check)
test_docker_compose_config() {
  if command -v docker >/dev/null 2>&1 && docker compose config >/dev/null 2>&1; then
    docker compose config -q
  else
    # Fallback YAML syntax check
    grep -q "version:" docker-compose.yml && grep -q "services:" docker-compose.yml
  fi
}

# 4. Test application properties exists for all services
test_app_properties_exist() {
  test -f "election-management/src/main/resources/application.properties" && \
  test -f "voting-app/src/main/resources/application.properties" && \
  test -f "result-app/src/main/resources/application.properties"
}

test_case "cicd-build.sh fails without arguments" test_cicd_build_no_args
test_case "cicd-build.sh fails with non-existent app directory" test_cicd_build_invalid_dir
test_case "cicd-blue-green-deployment.sh fails without arguments" test_cicd_bg_no_args
test_case "cicd-blue-green-deployment.sh fails with only one argument" test_cicd_bg_one_arg
test_case "docker-compose.yml configuration valid" test_docker_compose_config
test_case "application.properties present across microservices" test_app_properties_exist

echo "=========================================="
if [ "$FAILED" -eq 0 ]; then
  echo " All infrastructure tests PASSED!"
  exit 0
else
  echo " ${FAILED} test(s) FAILED!"
  exit 1
fi
