#!/usr/bin/env bash
# src: ./.github/actions/validate-environment/scripts/validate-permissions.sh
# @(#) : Validate GitHub token permissions for Actions workflows
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file validate-permissions.sh
# @brief Validate GitHub token permissions based on action requirements
# @description
#   Validates GitHub token permissions for different action types.
#   Supports read (contents: read), commit (contents: write), and PR
#   (contents: write + pull-requests: write) operations.
#
#   **Checks:**
#   1. GITHUB_TOKEN existence (always)
#   2. Write permissions via API execution probe (commit or pr)
#      - Sends a POST request that will be rejected as 422 if permitted,
#        or 403 if the token lacks the required permission.
#      - No resources are actually created (invalid payload triggers 422).
#
# @exitcode 0 Permission validation successful
# @exitcode 1 Permission validation failed
#
# @author   atsushifx
# @version  0.1.0
# @license  MIT

set -euo pipefail

# ============================================================================
# Section 1: GLOBAL VARIABLES
# ============================================================================

ACTIONS_TYPE="${ACTIONS_TYPE:-read}"

# ============================================================================
# Section 2: UTILITY FUNCTIONS
# ============================================================================

# @description Return GITHUB_OUTPUT path for grouped redirect
# @stdout Path to GITHUB_OUTPUT (fallback: /dev/null)
# @example { echo "status=success"; echo "message=OK"; } >> "$(out_status)"
out_status() {
  echo "${GITHUB_OUTPUT:-/dev/null}"
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

# @description Check if curl is available in PATH
# @exitcode 0 curl is available
# @exitcode 1 curl is not installed or not found in PATH
check_curl() {
  command -v curl >/dev/null 2>&1
}

# ============================================================================
# Section 3: GITHUB API LAYER
# ============================================================================

# @description Determine the base branch for PR permission probe
# @stdout Branch name (GITHUB_BASE_REF → GITHUB_REF_NAME)
# @exitcode 0 Branch determined
# @exitcode 1 Neither GITHUB_BASE_REF nor GITHUB_REF_NAME is set
determine_base_branch() {
  if [ -n "${GITHUB_BASE_REF:-}" ]; then
    echo "$GITHUB_BASE_REF"
  elif [ -n "${GITHUB_REF_NAME:-}" ]; then
    echo "$GITHUB_REF_NAME"
  else
    return 1
  fi
}

# @description Send POST request to GitHub API and return HTTP status code only
# @arg $1 string API endpoint path (e.g., "/repos/owner/repo/git/refs")
# @arg $2 string JSON payload to send
# @stdout HTTP status code (e.g., "422", "403", "201")
# @exitcode 0 Always (HTTP errors indicated via stdout status code)
github_api_post() {
  local endpoint="$1"
  local json_payload="$2"

  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_status}" \
    -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com${endpoint}" \
    --data "${json_payload}") || http_status="000"  # "000": Network error (curl failed)
  echo "$http_status"
}

# ============================================================================
# Section 4: PERMISSION PROBE
# ============================================================================

# @description Probe GitHub write permissions via API execution (no side effects)
# @arg $1 string Operation type: "commit" or "pr"
# @exitcode 0 Permission granted (HTTP 201/422/409 — API accepted the request)
# @exitcode 1 Permission denied (HTTP 403/401) or unknown operation
probe_github_write_permission() {
  local operation="$1"
  local owner_repo="${GITHUB_REPOSITORY}"
  if [ -z "$owner_repo" ]; then
    echo "::error::GITHUB_REPOSITORY is not set" >&2
    return 1
  fi
  local http_status

  case "$operation" in
    commit)
      local timestamp
      timestamp=$(date +%s)
      local payload
      payload="{\"ref\": \"refs/heads/permission-probe-${timestamp}\", \"sha\": \"0000000000000000000000000000000000000000\"}"
      http_status=$(github_api_post "/repos/${owner_repo}/git/refs" "$payload")
      ;;
    pr)
      local base_branch
      if ! base_branch=$(determine_base_branch); then
        echo "::error::Cannot determine base branch: set GITHUB_BASE_REF or GITHUB_REF_NAME" >&2
        return 1
      fi
      local timestamp
      timestamp=$(date +%s)
      local payload
      payload="{\"title\": \"permission-probe\", \"head\": \"permission-probe-${timestamp}\", \"base\": \"${base_branch}\"}"
      http_status=$(github_api_post "/repos/${owner_repo}/pulls" "$payload")
      ;;
    *)
      echo "::error::Unknown operation: ${operation}" >&2
      return 1
      ;;
  esac

  case "$http_status" in
    403)
      echo "::error::Permission denied (403): ${operation} permission not granted." >&2
      return 1
      ;;
    422|409|201)
      return 0  # Permission granted (API accepted; invalid payload caused rejection)
      ;;
    401)
      echo "::error::Authentication failed (401). Check GITHUB_TOKEN validity." >&2
      return 1
      ;;
    000) # Network error (curl failed)
      echo "::error::Network error: unable to reach GitHub API (curl failed)." >&2
      return 1
      ;;
    *)
      echo "::error::Unexpected HTTP response: ${http_status}" >&2
      return 1
      ;;
  esac
}

# ============================================================================
# Section 5: VALIDATION FUNCTIONS
# ============================================================================

# @description Validate GitHub token is available
# @exitcode 0 GITHUB_TOKEN environment variable is set
# @exitcode 1 GITHUB_TOKEN is not set or empty
# @stdout STATUS:message format (SUCCESS:... or ERROR:...)
validate_github_token() {
  if ! check_env_var "GITHUB_TOKEN"; then
    echo "ERROR:GITHUB_TOKEN environment variable is not set"
    return 1
  fi

  echo "SUCCESS:GITHUB_TOKEN is set"
  return 0
}

# @description Validate OIDC permissions are enabled
# @note This function is provided for reusability but NOT used by this action
# @exitcode 0 Both OIDC environment variables are set (id-token: write)
# @exitcode 1 One or both OIDC variables are missing
# @stdout STATUS:message format (SUCCESS:... or ERROR:...)
validate_id_token_permissions() {
  if ! check_env_var "ACTIONS_ID_TOKEN_REQUEST_URL"; then
    echo "ERROR:ACTIONS_ID_TOKEN_REQUEST_URL not set"
    return 1
  fi

  if ! check_env_var "ACTIONS_ID_TOKEN_REQUEST_TOKEN"; then
    echo "ERROR:ACTIONS_ID_TOKEN_REQUEST_TOKEN not set"
    return 1
  fi

  echo "SUCCESS:OIDC permissions validated"
  return 0
}

# @description Check GITHUB_TOKEN existence with progress output and GITHUB_OUTPUT write
# @exitcode 0 Token is present
# @exitcode 1 Token is missing
# @stdout Progress messages
# @stderr Error messages with ::error:: prefix
# @set GITHUB_OUTPUT Writes status=error and message on failure
check_token() {
  echo "Checking GITHUB_TOKEN..."
  local token_output token_status token_message
  token_output=$(validate_github_token) || true
  token_status="${token_output%%:*}"
  token_message="${token_output#*:}"

  if [ "$token_status" = "ERROR" ]; then
    echo "::error::${token_message}" >&2
    echo "::error::This action requires a GitHub token for API access" >&2
    echo "::error::Please ensure GITHUB_TOKEN is configured in the workflow" >&2
    { echo "status=error"; echo "message=${token_message}"; } >> "$(out_status)"
    return 1
  fi
  echo "✓ ${token_message}"
  echo ""
}

# ============================================================================
# Section 6: MAIN ORCHESTRATOR
# ============================================================================

# @description Main permissions validation orchestrator
# @exitcode 0 All required permissions validated
# @exitcode 1 One or more permissions are missing
# @stdout Validation progress messages
# @stderr Error messages with ::error:: prefix
# @set GITHUB_OUTPUT Writes status=success|error and message=<details>
validate_permissions() {
  local actions_type
  actions_type="${1:-${ACTIONS_TYPE:-read}}"
  actions_type="${actions_type,,}"

  # Validate actions-type argument
  case "$actions_type" in
    read|commit|pr|any) ;;
    *)
      echo "::error::Invalid actions-type: '${actions_type}'. Must be one of: read, commit, pr, any" >&2
      { echo "status=error"; echo "message=Invalid actions-type: ${actions_type}"; } >> "$(out_status)"
      return 1
      ;;
  esac

  # any: token check only, skip permission probe
  if [ "$actions_type" = "any" ]; then
    check_token || return 1
    echo "=== GitHub permissions validation passed (type=any: permission checks skipped) ==="
    { echo "status=success"; echo "message=GitHub permissions validated"; } >> "$(out_status)"
    return 0
  fi

  echo "=== Validating GitHub Permissions ==="
  echo ""

  check_token || return 1

  # Validate write permissions via API execution probe
  case "$actions_type" in
    "pr")
      echo "Checking permissions for PR operations..."
      if ! probe_github_write_permission "pr"; then
        echo "::error::pull-requests: write permission not granted" >&2
        echo "::error::For GITHUB_TOKEN, configure permissions: contents: write, pull-requests: write" >&2
        { echo "status=error"; echo "message=Missing PR permissions: pull-requests: write"; } >> "$(out_status)"
        return 1
      fi
      echo "✓ pull-requests: write permission verified"
      echo "✓ PR operations permissions validated"
      echo ""
      ;;
    "commit")
      echo "Checking permissions for commit operations..."
      if ! probe_github_write_permission "commit"; then
        echo "::error::contents: write permission not granted" >&2
        echo "::error::For GITHUB_TOKEN, configure permissions: contents: write" >&2
        { echo "status=error"; echo "message=Missing commit permissions: contents: write"; } >> "$(out_status)"
        return 1
      fi
      echo "✓ contents: write permission verified"
      echo "✓ Commit operations permissions validated"
      echo ""
      ;;
    "read")
      # contents: read is a required GitHub Actions permission.
      # No API check needed — declare it explicitly in your workflow.
      echo "contents: read is a required permission. Declare it explicitly in your workflow's permissions section."
      ;;
  esac

  echo "=== GitHub permissions validation passed ==="
  { echo "status=success"; echo "message=GitHub permissions validated"; } >> "$(out_status)"
  return 0
}

# ============================================================================
# Section 7: SCRIPT ENTRY POINT
# ============================================================================

# Only execute when script is run directly (not when sourced for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  check_curl || { echo "::error::curl is not installed or not found in PATH" >&2; exit 1; }
  validate_permissions "${1:-${ACTIONS_TYPE:-read}}"
  exit $?
fi
