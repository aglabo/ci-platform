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
#   Supports read (contents: read), commit (contents: write), and PR (contents: write + pull-requests: write) operations.
#
#   **Checks:**
#   1. GITHUB_TOKEN existence (always)
#   2. Token scopes based on action type (read, commit, or pr)
#   3. OIDC permissions (optional, not used by this action)
#
# @exitcode 0 Permission validation successful
# @exitcode 1 Permission validation failed
#
# @author   atsushifx
# @version  1.0.0
# @license  MIT

set -euo pipefail

# Global variables for validation results
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"
ACTIONS_TYPE="${ACTIONS_TYPE:-read}"
TOKEN_SCOPES=""       # GitHub API から取得したトークンスコープ
MISSING_SCOPES=""     # 不足しているスコープのリスト

# ============================================================================
# Helper Functions
# ============================================================================

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

# @description Parse token scopes from GitHub API response headers
# @arg $1 string Path to file containing curl response headers
# @exitcode 0 X-OAuth-Scopes header found and parsed
# @exitcode 1 Header not found or file does not exist
# @set TOKEN_SCOPES Space-separated list of scopes from X-OAuth-Scopes header
parse_oauth_scopes() {
  local header_file="$1"

  # Check if header file exists
  if [ ! -f "$header_file" ]; then
    return 1
  fi

  # Extract X-OAuth-Scopes header value
  local scopes_line
  scopes_line=$(grep -i "^X-OAuth-Scopes:" "$header_file" 2>/dev/null || echo "")

  if [ -z "$scopes_line" ]; then
    return 1
  fi

  # Extract scopes (remove header name, replace commas with spaces, trim whitespace)
  TOKEN_SCOPES=$(echo "$scopes_line" | sed 's/^X-OAuth-Scopes://i' | sed 's/,/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ')

  return 0
}

# @description Check if all required scopes are present in TOKEN_SCOPES
# @arg $@ list Required scope names to check
# @exitcode 0 All required scopes are present
# @exitcode 1 One or more scopes are missing
# @set MISSING_SCOPES Space-separated list of missing scopes
check_required_scopes() {
  MISSING_SCOPES=""

  # If TOKEN_SCOPES is empty, all scopes are missing
  if [ -z "$TOKEN_SCOPES" ]; then
    MISSING_SCOPES="$*"
    return 1
  fi

  # Convert TOKEN_SCOPES to array-like string for checking
  local has_missing=0
  for required_scope in "$@"; do
    # Check if scope exists in TOKEN_SCOPES (word boundary matching)
    if ! echo " $TOKEN_SCOPES " | grep -q " $required_scope "; then
      MISSING_SCOPES="${MISSING_SCOPES}${required_scope} "
      has_missing=1
    fi
  done

  # Trim trailing space from MISSING_SCOPES
  MISSING_SCOPES=$(echo "$MISSING_SCOPES" | sed 's/[[:space:]]*$//')

  return "$has_missing"
}

# @description Call GitHub API and retrieve response headers
# @arg $1 string API endpoint path (default: "/")
# @arg $2 string Output file path for response headers
# @exitcode 0 API call succeeded
# @exitcode 1 Network error or API failure
call_github_api() {
  local endpoint="${1:-/}"
  local output_file="$2"

  if ! curl -fsSL -I \
       -H "Authorization: token ${GITHUB_TOKEN}" \
       "https://api.github.com${endpoint}" > "$output_file" 2>&1; then
    return 1
  fi

  return 0
}

# ============================================================================
# Validation Functions
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

# @description Validate GitHub token has required scopes via API
# @arg $@ list Required scope names (e.g., "repo" "contents")
# @exitcode 0 All required scopes are present
# @exitcode 1 API call failed, scopes missing, or network error
# @set TOKEN_SCOPES Retrieved scopes from GitHub API
# @set MISSING_SCOPES List of missing scopes (if any)
# @stdout STATUS:message format (SUCCESS:... or ERROR:...)
validate_token_scopes() {
  local required_scopes=("$@")
  local temp_header_file
  local api_result parse_result

  # Create temporary file for response headers
  temp_header_file=$(mktemp)

  # Use dedicated API call function
  call_github_api "/" "$temp_header_file"
  api_result=$?

  if [ $api_result -ne 0 ]; then
    rm -f "$temp_header_file"
    echo "ERROR:GitHub API call failed"
    return 1
  fi

  # Check for rate limit in response
  if grep -qi "rate limit" "$temp_header_file"; then
    rm -f "$temp_header_file"
    echo "ERROR:GitHub API rate limit exceeded"
    return 1
  fi

  # Parse scopes from response headers
  parse_oauth_scopes "$temp_header_file"
  parse_result=$?
  rm -f "$temp_header_file"

  if [ $parse_result -ne 0 ]; then
    echo "ERROR:Failed to parse token scopes from API response"
    return 1
  fi

  # Check if all required scopes are present
  if ! check_required_scopes "${required_scopes[@]}"; then
    echo "ERROR:Missing required scopes: ${MISSING_SCOPES}"
    return 1
  fi

  echo "SUCCESS:All required scopes present"
  return 0
}

# ============================================================================
# Main Orchestrator Function
# ============================================================================

# @description Main permissions validation orchestrator
# @exitcode 0 All required permissions validated
# @exitcode 1 One or more permissions are missing
# @stdout Validation progress messages
# @stderr Error messages with ::error:: prefix
# @set GITHUB_OUTPUT Writes status=success|error and message=<details>
validate_permissions() {
  local actions_type="${1:-${ACTIONS_TYPE:-read}}"

  # Validate actions-type argument
  case "$actions_type" in
    read|commit|pr) ;;
    *)
      echo "::error::Invalid actions-type: '${actions_type}'. Must be one of: read, commit, pr" >&2
      echo "status=error" >> "${GITHUB_OUTPUT}"
      echo "message=Invalid actions-type: ${actions_type}" >> "${GITHUB_OUTPUT}"
      return 1
      ;;
  esac

  echo "=== Validating GitHub Permissions ==="
  echo ""

  # Always validate GITHUB_TOKEN existence
  echo "Checking GITHUB_TOKEN..."
  local token_output token_status token_message
  token_output=$(validate_github_token) || true
  token_status="${token_output%%:*}"
  token_message="${token_output#*:}"

  if [ "$token_status" = "ERROR" ]; then
    echo "::error::${token_message}" >&2
    echo "::error::This action requires a GitHub token for API access" >&2
    echo "::error::Please ensure GITHUB_TOKEN is configured in the workflow" >&2
    echo "status=error" >> "${GITHUB_OUTPUT}"
    echo "message=${token_message}" >> "${GITHUB_OUTPUT}"
    return 1
  fi
  echo "✓ ${token_message}"
  echo ""

  # Validate token scopes based on action type
  case "$actions_type" in
    "pr")
      echo "Checking permissions for PR operations..."
      local scopes_output scopes_status scopes_message
      scopes_output=$(validate_token_scopes "repo") || true
      scopes_status="${scopes_output%%:*}"
      scopes_message="${scopes_output#*:}"

      if [ "$scopes_status" = "ERROR" ]; then
        echo "::error::${scopes_message}" >&2
        echo "::error::Required scopes: repo (includes contents and pull-requests)" >&2
        echo "::error::Please configure permissions: contents: write, pull-requests: write" >&2
        echo "status=error" >> "${GITHUB_OUTPUT}"
        echo "message=Missing PR permissions: ${MISSING_SCOPES}" >> "${GITHUB_OUTPUT}"
        return 1
      fi
      echo "✓ ${scopes_message}"
      echo "✓ Token has required scopes: ${TOKEN_SCOPES}"
      echo "✓ PR operations permissions validated"
      echo ""
      ;;
    "commit")
      echo "Checking permissions for commit operations..."
      local scopes_output scopes_status scopes_message
      scopes_output=$(validate_token_scopes "repo") || true
      scopes_status="${scopes_output%%:*}"
      scopes_message="${scopes_output#*:}"

      if [ "$scopes_status" = "ERROR" ]; then
        echo "::error::${scopes_message}" >&2
        echo "::error::Required scopes: repo (includes contents)" >&2
        echo "::error::Please configure permissions: contents: write" >&2
        echo "status=error" >> "${GITHUB_OUTPUT}"
        echo "message=Missing commit permissions: ${MISSING_SCOPES}" >> "${GITHUB_OUTPUT}"
        return 1
      fi
      echo "✓ ${scopes_message}"
      echo "✓ Token has required scopes: ${TOKEN_SCOPES}"
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
  echo "status=success" >> "${GITHUB_OUTPUT}"
  echo "message=GitHub permissions validated" >> "${GITHUB_OUTPUT}"
  return 0
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Only execute when script is run directly (not when sourced for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  validate_permissions "${1:-${ACTIONS_TYPE:-read}}"
  exit $?
fi
