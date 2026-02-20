#!/usr/bin/env bash
# src: ./.github/actions/validate-environment/scripts/validate-git-runner.sh
# @(#) : Validate GitHub Actions runner environment
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file validate-git-runner.sh
# @brief Validate GitHub Actions runner environment comprehensively
# @description
#   Validates the execution environment for GitHub Actions workflows.
#   Prerequisite: Linux runner only (Ubuntu). Windows and macOS are not supported.
#   Checks architecture (amd64|arm64), GitHub Actions environment,
#   and optionally GitHub-hosted runner (enabled when REQUIRE_GITHUB_HOSTED=true).
#
#   **Checks:**
#   1. Operating System is Linux
#   2. Expected architecture input is valid (amd64 or arm64)
#   3. Detected architecture matches expected architecture
#   4. GitHub Actions environment (GITHUB_ACTIONS=true)
#   5. GitHub-hosted runner (optional; required when REQUIRE_GITHUB_HOSTED=true)
#   6. Required runtime variables (RUNNER_TEMP, GITHUB_OUTPUT, GITHUB_PATH)
#
# @exitcode 0 GitHub runner validation successful
# @exitcode 1 GitHub runner validation failed
#
# @author   atsushifx
# @version  0.1.0
# @license  MIT

set -euo pipefail

# Global variables for validation results
if [ "${BASH_SOURCE[0]}" = "${0}" ] && [ -z "${GITHUB_OUTPUT:-}" ]; then
  echo "Warning: GITHUB_OUTPUT is not set; outputs will be discarded" >&2
fi
EXPECTED_ARCH="${EXPECTED_ARCHITECTURE:-amd64}"
REQUIRE_GITHUB_HOSTED="${REQUIRE_GITHUB_HOSTED:-true}"
NORMALIZED_ARCH=""
DETECTED_OS=""
DETECTED_ARCH=""

# ============================================================================
# Helper Functions
# ============================================================================

# @description Detect operating system
# @arg $1 string Optional OS name override (for testing/debugging)
# @exitcode 0 Always succeeds
# @stdout Normalized OS name (lowercase)
detect_os() {
  echo "${1:-$(uname -s)}" | tr '[:upper:]' '[:lower:]'
}

# @description Detect system architecture
# @arg $1 string Optional architecture name override (for testing/debugging)
# @exitcode 0 Always succeeds
# @stdout Raw architecture name
detect_architecture() {
  echo "${1:-$(uname -m)}"
}

# @description Normalize architecture to canonical form
# @arg $1 string Raw architecture name (e.g., "x86_64", "aarch64")
# @exitcode 0 Valid architecture
# @exitcode 1 Unsupported architecture
# @stdout Canonical architecture (amd64|arm64) on success, empty on failure
normalize_architecture() {
  local raw_arch="$1"

  case "${raw_arch}" in
    x86_64|amd64|x64)
      echo "amd64"
      return 0
      ;;
    aarch64|arm64)
      echo "arm64"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# @description Write status and message to GITHUB_OUTPUT
# @arg $1 string Status value (success|error)
# @arg $2 string Message string
# @exitcode 0 Always succeeds
# @note GITHUB_OUTPUT is evaluated at call time (not at source time) to allow
#       test environments to set the variable after sourcing this script.
write_output() {
  echo "status=$1" >> "${GITHUB_OUTPUT:-/dev/null}"
  echo "message=$2" >> "${GITHUB_OUTPUT:-/dev/null}"
}

# @description Check environment variable existence and value
# @arg $1 string Variable name to check
# @arg $2 string Expected value (optional, checks existence only if omitted)
# @exitcode 0 Variable exists and matches expected value (if provided)
# @exitcode 1 Variable not set or value mismatch
check_env_var() {
  local var_name="$1"
  local expected_value="${2:-}"
  local var_value="${!var_name:-}"

  # Check if variable is set
  [ -n "$var_value" ] || return 1

  # If expected value provided, check if it matches
  [ -z "$expected_value" ] || [ "$var_value" = "$expected_value" ] || return 1

  return 0
}

# ============================================================================
# Validation Functions
# ============================================================================

# @description Validate operating system is Linux
# @arg $1 string Detected OS name (lowercase)
# @exitcode 0 Operating system is Linux
# @exitcode 1 Operating system is not Linux
# @stdout STATUS:message format (SUCCESS:message or ERROR:message)
validate_os() {
  local detected_os="$1"

  if [ "${detected_os}" = "linux" ]; then
    echo "SUCCESS:Operating system is Linux"
    return 0
  else
    echo "ERROR:Unsupported OS: ${detected_os} (Linux required)"
    return 1
  fi
}

# @description Validate expected architecture input
# @exitcode 0 EXPECTED_ARCH is valid (amd64 or arm64)
# @exitcode 1 EXPECTED_ARCH is invalid
validate_expected_arch() {
  case "${EXPECTED_ARCH}" in
    amd64|arm64)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# @description Validate architecture can be normalized
# @arg $1 string Raw architecture name
# @exitcode 0 Architecture is valid (can be normalized)
# @exitcode 1 Architecture is unsupported
is_supported_architecture() {
  normalize_architecture "$1" > /dev/null
}

# @description Validate architecture matches expected value
# @exitcode 0 EXPECTED_ARCH matches NORMALIZED_ARCH
# @exitcode 1 Architecture mismatch
validate_arch_match() {
  [ "${EXPECTED_ARCH}" = "${NORMALIZED_ARCH}" ]
}

# @description Validate GitHub Actions environment
# @exitcode 0 GITHUB_ACTIONS environment variable is set to 'true'
# @exitcode 1 Not running in GitHub Actions environment
validate_github_actions_env() {
  check_env_var "GITHUB_ACTIONS" "true"
}

# @description Validate GitHub-hosted runner
# @note RUNNER_ENVIRONMENT is set automatically by GitHub Actions on GitHub-hosted runners.
#       This variable is NOT available on self-hosted runners (GitHub spec dependency).
# @exitcode 0 RUNNER_ENVIRONMENT is set to 'github-hosted'
# @exitcode 1 Self-hosted runner or RUNNER_ENVIRONMENT not set correctly
validate_github_hosted_runner() {
  check_env_var "RUNNER_ENVIRONMENT" "github-hosted"
}

# @description Validate required runtime variables
# @exitcode 0 All required variables (RUNNER_TEMP, GITHUB_OUTPUT, GITHUB_PATH) are set
# @exitcode 1 One or more required variables are missing
validate_runtime_variables() {
  for var in RUNNER_TEMP GITHUB_OUTPUT GITHUB_PATH; do
    if ! check_env_var "$var"; then
      return 1
    fi
  done

  return 0
}

# ============================================================================
# Main Orchestrator Function
# ============================================================================

# @description Main validation orchestrator
# @exitcode 0 All validations passed
# @exitcode 1 One or more validations failed
# @stdout Validation progress messages
# @stderr Error messages with ::error:: prefix
# @set GITHUB_OUTPUT Writes status=success|error and message=<details>
validate_git_runner() {
  echo "=== Validating GitHub Runner Environment ==="
  echo ""

  # Detect and validate OS
  DETECTED_OS=$(detect_os)

  local os_output os_message
  if os_output=$(validate_os "${DETECTED_OS}"); then
    os_message="${os_output#SUCCESS:}"
    echo "Operating System: ${DETECTED_OS}"
    echo "✓ ${os_message}"
    echo ""
  else
    os_message="${os_output#ERROR:}"
    echo "::error::${os_message}" >&2
    echo "::error::This action requires Linux" >&2
    echo "::error::Please use a Linux runner (e.g., ubuntu-latest)" >&2
    write_output "error" "${os_message}"
    return 1
  fi

  # Validate expected architecture input
  if ! validate_expected_arch; then
    echo "::error::Invalid architecture input: ${EXPECTED_ARCH}" >&2
    echo "::error::Supported values: amd64, arm64" >&2
    write_output "error" "Invalid architecture input: ${EXPECTED_ARCH}"
    return 1
  fi

  echo "Expected architecture: ${EXPECTED_ARCH}"

  # Detect and validate architecture
  DETECTED_ARCH=$(detect_architecture)

  if ! is_supported_architecture "${DETECTED_ARCH}"; then
    echo "::error::Unsupported architecture: ${DETECTED_ARCH}" >&2
    echo "::error::Supported architectures: amd64 (x86_64), arm64 (aarch64)" >&2
    write_output "error" "Unsupported architecture: ${DETECTED_ARCH}"
    return 1
  fi

  NORMALIZED_ARCH=$(normalize_architecture "${DETECTED_ARCH}")

  echo "Detected architecture: ${DETECTED_ARCH}"

  # Validate architecture match
  if ! validate_arch_match; then
    echo "::error::Architecture mismatch" >&2
    echo "::error::Expected: ${EXPECTED_ARCH}" >&2
    echo "::error::Detected: ${NORMALIZED_ARCH} (${DETECTED_ARCH})" >&2
    echo "::error::Please use a runner with ${EXPECTED_ARCH} architecture" >&2
    write_output "error" "Architecture mismatch: expected ${EXPECTED_ARCH}, got ${NORMALIZED_ARCH}"
    return 1
  fi

  echo "✓ Architecture validated: ${NORMALIZED_ARCH}"
  echo ""

  # Check GitHub Actions environment
  echo "Checking GitHub Actions environment..."

  if ! validate_github_actions_env; then
    echo "::error::Not running in GitHub Actions environment" >&2
    echo "::error::This action must run in a GitHub Actions workflow" >&2
    echo "::error::GITHUB_ACTIONS environment variable is not set to 'true'" >&2
    write_output "error" "Not running in GitHub Actions environment"
    return 1
  fi

  echo "✓ GITHUB_ACTIONS is set to 'true'"

  if [ "${REQUIRE_GITHUB_HOSTED}" = "true" ]; then
    if ! validate_github_hosted_runner; then
      echo "::error::This action requires a GitHub-hosted runner" >&2
      echo "::error::Self-hosted runners are not supported" >&2
      echo "::error::RUNNER_ENVIRONMENT is not set to 'github-hosted' (current: ${RUNNER_ENVIRONMENT:-unset})" >&2
      write_output "error" "Requires GitHub-hosted runner (not self-hosted)"
      return 1
    fi
    echo "✓ RUNNER_ENVIRONMENT is 'github-hosted'"
  fi

  if ! validate_runtime_variables; then
    echo "::error::Required environment variables are not set" >&2
    echo "::error::This action must run in a GitHub Actions environment" >&2
    write_output "error" "Missing required environment variables"
    return 1
  fi

  echo "✓ RUNNER_TEMP is set"
  echo "✓ GITHUB_OUTPUT is set"
  echo "✓ GITHUB_PATH is set"
  echo ""

  echo "=== GitHub runner validation passed ==="
  write_output "success" "GitHub runner validated: Linux ${NORMALIZED_ARCH}"
  return 0
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Only execute when script is run directly (not when sourced for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  validate_git_runner
  exit $?
fi
