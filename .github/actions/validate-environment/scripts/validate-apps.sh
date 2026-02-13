#!/usr/bin/env bash
# src: ./.github/actions/validate-environment/scripts/validate-apps.sh
# @(#) : Validate required applications (Git, curl, gh CLI, etc.)
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# @file validate-apps.sh
# @brief Validate required applications for GitHub Actions with safe version extraction
# @description
#   Validates that required applications are installed with configurable fail-fast behavior.
#   Uses SAFE extraction methods WITHOUT eval - prevents arbitrary code execution.
#
#   **Default Checks:**
#   1. Git is installed (version 2.30+ required)
#   2. curl is installed
#   3. gh (GitHub CLI) is installed (version 2.0+ required)
#
#   **Features:**
#   - Gate action design: exits immediately on first validation error
#   - Generic version checking using sort -V (handles semver, prerelease, etc.)
#   - Safe declarative version extraction (NO EVAL)
#   - Backward compatible with field-number extraction (legacy)
#   - Machine-readable outputs for downstream actions
#   - Extensible: additional applications can be specified as arguments
#
#   **Version Extraction (Security Hardened):**
#   - Prefix-typed extractors: field:N or regex:PATTERN (explicit method declaration)
#   - sed-only with # delimiter (allows / in patterns)
#   - NO eval usage - prevents arbitrary code execution
#   - Input validation: Rejects shell metacharacters, control chars, sed delimiter (#)
#   - sed injection prevention: # character rejection prevents breaking out of pattern
#   - Examples: "regex:version ([0-9.]+)" extracts version number from "git version 2.52.0"
#
#   **Environment Variables:**
#   - FAIL_FAST: Internal implementation detail (always true for gate behavior)
#   - GITHUB_OUTPUT: Output file for GitHub Actions (optional, fallback to /dev/null)
#
#   **Outputs (machine-readable):**
#   - status: "success" or "error"
#   - message: Human-readable summary
#   - validated_apps: Comma-separated list of validated app names
#   - validated_count: Number of successfully validated apps
#   - failed_apps: Comma-separated list of failed app names (on error)
#   - failed_count: Number of failed apps
#
# @exitcode 0 Application validation successful
# @exitcode 1 Application validation failed (one or more apps missing or invalid)
#
# @author   atsushifx
# @version  1.2.2
# @license  MIT

set -euo pipefail

<<<<<<< HEAD
# Safe output file handling - use function to support dynamic evaluation in tests
get_github_output_file() {
  echo "${GITHUB_OUTPUT:-/dev/null}"
}

# Fail-fast mode: INTERNAL ONLY (not exposed as action input)
# This action is a gate - errors mean the workflow cannot continue
# Always defaults to true (fail on first error)
FAIL_FAST="${FAIL_FAST:-true}"


# Applications to validate (populated by initialize_apps_list function)
declare -a APPS=()

# Validation results storage (JSON-based)
declare -a VALIDATION_RESULTS=()    # Array of JSON strings
VALIDATION_INDEX=0                  # Sequential index counter

# @description Check if jq is available (required for JSON processing)
# @exitcode 0 jq is available
# @exitcode 1 jq is not installed
# @stderr Error message with installation instructions
check_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "::error::jq is required for JSON processing" >&2
    echo "::error::Install: sudo apt-get install jq  (or: brew install jq)" >&2
    echo "::error::See README.md for details" >&2
    return 1
  fi
  return 0
}

# Extract version number from full version string
# Parameters: $1=full_version (e.g., "git version 2.52.0"), $2=version_extractor
# Output format:
#   Line 1: Extracted version number on success, "ERROR" on failure
#   Line 2+: Log messages (::error::, ::warning::, etc.)
# Exit code: 0=success, 1=failure
# Note: Safe extraction using sed only - no eval, prefix-typed extractors only
#
# Supported formats (prefix-typed):
#   field:N         - Extract Nth field (space-delimited, 1-indexed)
#   regex:PATTERN   - sed -E 's/PATTERN/\1/' with capture group
#   (empty)         - Default: extract semver (X.Y or X.Y.Z)
#
# Examples:
#   extract_version_number "git version 2.52.0" "field:3"
#   → 2.52.0
#
#   extract_version_number "unknown" ""
#   → ERROR
#   → ::error::No semver pattern found in: unknown
extract_version_number() {
  local full_version="$1"
  local version_extractor="$2"

  # Default: extract semver (X.Y or X.Y.Z) if extractor is empty
  if [ -z "$version_extractor" ]; then
    local extracted
    extracted=$(echo "$full_version" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

    if [ -z "$extracted" ]; then
      echo "ERROR"
      echo "::error::No semver pattern found in: $full_version"
      return 1
    fi

    echo "$extracted"
    return 0
  fi

  # Parse extractor format: method:argument
  local method="${version_extractor%%:*}"
  local argument="${version_extractor#*:}"

  case "$method" in
    field)
      # Extract Nth field (space-delimited)
      if [[ ! "$argument" =~ ^[0-9]+$ ]]; then
        echo "ERROR"
        echo "::error::Invalid field number: $argument"
        return 1
      fi
      local result
      result=$(echo "$full_version" | cut -d' ' -f"$argument")
      echo "$result"
      return 0
      ;;

    regex)
      # Extract using sed -E regex with capture group
      # Use # delimiter to allow / in regex patterns
      if [ -z "$argument" ]; then
        echo "ERROR"
        echo "::error::Empty regex pattern"
        return 1
      fi

      # Security: Validate regex pattern to prevent injection
      # Reject our delimiter (#) to prevent breaking out of sed pattern
      if [[ "$argument" == *"#"* ]]; then
        echo "ERROR"
        echo "::error::Regex pattern cannot contain '#' character (reserved as sed delimiter)"
        return 1
      fi

      # Reject shell metacharacters that shouldn't appear in version extraction regex
      if [[ "$argument" =~ [\;\|\&\$\`\\] ]]; then
        echo "ERROR"
        echo "::error::Regex pattern contains dangerous shell metacharacters: $argument"
        return 1
      fi

      # Reject newlines and control characters
      if [[ "$argument" =~ $'\n'|$'\r'|$'\t' ]]; then
        echo "ERROR"
        echo "::error::Regex pattern contains control characters"
        return 1
      fi

      # Wrap pattern with .* for full line matching if not already present
      local sed_pattern="$argument"
      if [[ ! "$sed_pattern" =~ ^\.\* ]]; then
        sed_pattern=".*${sed_pattern}"
      fi
      if [[ ! "$sed_pattern" =~ \.\*$ ]]; then
        sed_pattern="${sed_pattern}.*"
      fi

      local extracted
      extracted=$(echo "$full_version" | sed -E "s#${sed_pattern}#\1#")

      # Check if extraction succeeded (result differs from input)
      if [ "$extracted" = "$full_version" ]; then
        echo "ERROR"
        echo "::error::Pattern did not match: $argument"
        return 1
      fi

      echo "$extracted"
      return 0
      ;;

    *)
      echo "ERROR"
      echo "::error::Unknown extraction method: $method (expected: field, regex, or empty)"
      return 1
      ;;
  esac
}

# Check version meets minimum requirement (pure comparison function)
# Parameters: $1=version (e.g., "2.52.0"), $2=min_version (e.g., "2.30")
# Output format:
#   Line 1: "SUCCESS" if version >= min_version, "FAILURE" if version < min_version
#   Line 2+: Log messages (optional)
# Exit code: 0=success, 1=failure
# Note: Uses sort -V for stable version comparison (handles semver, prerelease, etc.)
#       Requires GNU coreutils (available on all GitHub-hosted runners)
check_version() {
  local version="$1"
  local min_version="$2"

  # Use sort -V (version sort) to compare
  # If min_version comes first or equal, version meets requirement
  # printf outputs: min_version, version (in that order)
  # sort -V sorts them in version order
  # If first line after sort == min_version, then version >= min_version
  local sorted_min=$(printf '%s\n%s\n' "$min_version" "$version" | sort -V | head -1)

  if [ "$sorted_min" = "$min_version" ]; then
    echo "SUCCESS"
    return 0  # version >= min_version
  else
    echo "FAILURE"
    return 1  # version < min_version
  fi
}

# @description Get application version string
# @arg $1 string Command name
# @exitcode 0 Version retrieved successfully
# @exitcode 1 Command failed or version unavailable
# @stdout Full version string (e.g., "git version 2.52.0")
get_app_version() {
  local cmd="$1"

  # Get full version string
  local version_output
  if ! version_output=$("$cmd" --version 2>&1 | head -1); then
    return 1
  fi

  # Output version string to stdout
  echo "$version_output"
  return 0
}

# @description Check GitHub CLI authentication status
# @exitcode 0 gh is authenticated
# @exitcode 1 gh is not authenticated or authentication check failed
check_gh_authentication() {
  # Check authentication status using gh auth status
  # Exit code 0 = authenticated, 1 = not authenticated or auth issues
  gh auth status >/dev/null 2>&1
  return $?
}

# @description Validate application exists and command name is safe
# @arg $1 string Command name
# @arg $2 string Application display name
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Command is valid and exists
# @exitcode 1 Failed (command not found or invalid name)
validate_app_exists() {
  local cmd="$1"
  local app_name="$2"

  # Security: Reject relative paths (./  and ../)
  # These can be used for directory traversal attacks
  if [[ "$cmd" == ./* ]] || [[ "$cmd" == ../* ]] || [[ "$cmd" == */./* ]] || [[ "$cmd" == */../* ]]; then
    echo "ERROR:Invalid command name contains shell metacharacters: $cmd"
    echo "::error::Invalid command name contains shell metacharacters: $cmd" >&2
    return 1
  fi

  # Security: Validate command name (reject shell metacharacters)
  # This prevents command injection via malicious app definitions
  #
  # Rejected: ; | & $ ` ( ) space tab (common injection vectors)
  # Intentionally allowed: / - _ (for absolute paths like /usr/bin/gh)
  # Design: Balance security with practicality for legitimate command names
  if [[ "$cmd" =~  [\;\|\&\$\`\(\)[:space:]] ]]; then
    echo "ERROR:Invalid command name contains shell metacharacters: $cmd"
    echo "::error::Invalid command name contains shell metacharacters: $cmd" >&2
    return 1
  fi

  echo "Checking ${app_name}..." >&2

  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR:${app_name} is not installed"
    echo "::error::${app_name} is not installed" >&2
    return 1
  fi

  echo "SUCCESS:${app_name} command found"
  return 0
}

# @description Validate application version
# @arg $1 string Command name
# @arg $2 string Application display name
# @arg $3 string Version extractor (field:N, regex:PATTERN, or empty)
# @arg $4 string Minimum required version (empty = skip check)
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/WARNING/ERROR, message is detail
# @exitcode 0 Version meets requirements
# @exitcode 1 Failed (extraction error or version too low)
validate_app_version() {
  local cmd="$1"
  local app_name="$2"
  local version_extractor="$3"
  local min_ver="$4"

  # Get full version string using helper function
  local version_string
  if ! version_string=$(get_app_version "$cmd"); then
    echo "ERROR:Failed to get version for ${app_name}"
    echo "::error::Failed to get version for ${app_name}" >&2
    return 1
  fi

  echo "  ✓ ${version_string}" >&2
  echo "" >&2

  # Check minimum version if min_ver is specified
  if [ -n "$min_ver" ]; then
    # Extract version number from full version string
    local extract_output version_num log_lines
    extract_output=$(extract_version_number "$version_string" "$version_extractor")
    local extract_status=$?

    version_num=$(echo "$extract_output" | head -1)
    log_lines=$(echo "$extract_output" | tail -n +2)

    if [ $extract_status -ne 0 ] || [ "$version_num" = "ERROR" ]; then
      echo "ERROR:Version extraction failed for ${app_name}"
      if [ -n "$log_lines" ]; then
        echo "$log_lines" >&2
      fi
      return 1
    fi

    # Validate version against minimum requirement
    local check_output check_result
    check_output=$(check_version "$version_num" "$min_ver")
    local check_status=$?
    check_result=$(echo "$check_output" | head -1)

    if [ $check_status -ne 0 ] || [ "$check_result" = "FAILURE" ]; then
      echo "ERROR:${app_name} version ${version_num} is below minimum required ${min_ver}"
      echo "::error::${app_name} version ${version_num} is below minimum required ${min_ver}" >&2
      return 1
    fi

    echo "SUCCESS:${app_name} version ${version_num} meets minimum ${min_ver}"
    return 0
  fi

  # Version check skipped - return warning
  echo "WARNING:${app_name} version check skipped (no minimum version specified)"
  echo "  ::warning::${app_name}: version check skipped (no minimum version specified)" >&2
  return 0
}

# @description Perform tool-specific validation checks (e.g., gh auth check)
# @arg $1 string Command name
# @arg $2 string Application display name
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Validation passed or no special check needed
# @exitcode 1 Validation failed
# @stderr Log messages (::error::, info)
validate_app_special() {
  local cmd="$1"
  local app_name="$2"

  case "$cmd" in
    gh)
      # GitHub CLI: Check authentication status
      echo "Checking ${app_name} authentication..." >&2

      if ! check_gh_authentication; then
        echo "ERROR:${app_name} is not authenticated"
        echo "::error::${app_name} is not authenticated. Run 'gh auth login' to authenticate." >&2
        return 1
      fi

      echo "  ✓ ${app_name} is authenticated" >&2
      echo "" >&2
      echo "SUCCESS:${app_name} is authenticated"
      return 0
      ;;

    # Future extension points:
    #
    # docker)
    #   # Docker: Check daemon is running
    #   echo "Checking ${app_name} daemon..." >&2
    #   if ! docker info >/dev/null 2>&1; then
    #     echo "ERROR:Docker daemon is not running"
    #     echo "::error::Docker daemon is not running. Start Docker Desktop or dockerd." >&2
    #     return 1
    #   fi
    #   echo "  ✓ ${app_name} daemon is running" >&2
    #   echo "" >&2
    #   echo "SUCCESS:${app_name} daemon is running"
    #   return 0
    #   ;;
    #
    # aws)
    #   # AWS CLI: Check credentials are configured
    #   echo "Checking ${app_name} credentials..." >&2
    #   if ! aws sts get-caller-identity >/dev/null 2>&1; then
    #     echo "ERROR:AWS credentials not configured"
    #     echo "::error::AWS credentials not configured. Run 'aws configure'." >&2
    #     return 1
    #   fi
    #   echo "  ✓ ${app_name} credentials configured" >&2
    #   echo "" >&2
    #   echo "SUCCESS:${app_name} credentials configured"
    #   return 0
    #   ;;

    *)
      # No special validation needed for this command
      echo "SUCCESS:No special validation required"
      return 0
      ;;
  esac
}

# @description Validate app definition format (field count only)
# @arg $1 string App definition line (cmd|app_name|version_extractor|min_version)
# @stdout Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Valid format (SUCCESS)
# @exitcode 1 Invalid format (ERROR)
validate_app_format() {
  local line="$1"

  # Count pipe delimiters to determine field count
  local field_count
  field_count=$(echo "$line" | grep -o '|' | wc -l)
  field_count=$((field_count + 1))  # fields = delimiters + 1

  # Validate field count: must be exactly 2 or 4
  if [ "$field_count" -ne 2 ] && [ "$field_count" -ne 4 ]; then
    echo "ERROR:Invalid app definition format (expected 2 or 4 fields, got ${field_count})"
    echo "::error::Invalid app definition format (expected 2 or 4 pipe-delimited fields, got ${field_count}): $line" >&2
    return 1
  fi

  echo "SUCCESS:Valid app definition format"
  return 0
}

# @description Validate application line (format + control characters)
# @arg $1 string Application definition line (pipe-delimited)
# @exitcode 0 Line is valid
# @exitcode 1 Line is invalid (format error or control characters detected)
# @stderr Error messages
# Validates:
#   1. Field count (2 or 4 fields via validate_app_format)
#   2. Control characters in cmd (newline/CR/tab)
#   3. Control characters in app_name (newline/CR/tab)
# Security: Prevents command injection and log injection attacks
validate_app_line() {
  local line="$1"

  # 1. Validate format (field count) first
  local format_output format_exit_code format_status_line format_status format_message
  format_output=$(validate_app_format "$line")
  format_exit_code=$?
  format_status_line=$(echo "$format_output" | head -1)
  format_status="${format_status_line%%:*}"
  format_message="${format_status_line#*:}"

  if [ "$format_exit_code" -ne 0 ] || [ "$format_status" = "ERROR" ]; then
    echo "::error::${format_message}" >&2
    return 1
  fi

  # 2. Extract fields for control character validation
  # Use parameter expansion instead of read to preserve control characters
  local cmd app_name
  cmd="${line%%|*}"                    # Extract first field (everything before first |)
  local remaining="${line#*|}"         # Remove first field and delimiter
  app_name="${remaining%%|*}"          # Extract second field

  # 3. Validate cmd for control characters (security: prevent command injection)
  if [[ "$cmd" =~ $'\n'|$'\r'|$'\t' ]]; then
    echo "::error::Invalid command name '${cmd}': contains control characters (newline/CR/tab)" >&2
    echo "::error::This indicates malicious input or data corruption" >&2
    return 1
  fi

  # 4. Validate app_name for control characters (security: prevent log injection)
  if [[ "$app_name" =~ $'\n'|$'\r'|$'\t' ]]; then
    echo "::error::Invalid app_name '${app_name}': contains control characters (newline/CR/tab)" >&2
    echo "::error::This indicates malicious input or data corruption" >&2
    return 1
  fi

  return 0
}

# @description Add validation result to JSON array (unified storage)
# @arg $1 string Command name
# @arg $2 string Application name
# @arg $3 string Status (success|error)
# @arg $4 string Version string (empty for errors)
# @arg $5 string Error message (empty for success)
# @global VALIDATION_RESULTS array JSON storage
# @global VALIDATION_INDEX number Sequential index counter
add_validation_result() {
  local cmd="$1"
  local app_name="$2"
  local status="$3"
  local version="$4"
  local message="$5"

  # Validate: app_name must not contain control characters (security: prevent log injection)
  if [[ "$app_name" =~ $'\n'|$'\r'|$'\t' ]]; then
    echo "::error::Invalid app_name '${app_name}': contains control characters (newline/CR/tab)" >&2
    echo "::error::This indicates a bug in data retrieval or a potential security issue" >&2
    return 1
  fi

  local result_json
  if [ "$status" = "error" ]; then
    result_json=$(jq -n \
      --arg index "$VALIDATION_INDEX" \
      --arg cmd "$cmd" \
      --arg app "$app_name" \
      --arg status "$status" \
      --arg version "$version" \
      --arg message "$message" \
      '{index: ($index | tonumber), cmd: $cmd, app: $app, status: $status, version: $version, message: $message}')
  else
    result_json=$(jq -n \
      --arg index "$VALIDATION_INDEX" \
      --arg cmd "$cmd" \
      --arg app "$app_name" \
      --arg status "$status" \
      --arg version "$version" \
      '{index: ($index | tonumber), cmd: $cmd, app: $app, status: $status, version: $version}')
  fi

  VALIDATION_RESULTS+=("$result_json")
  VALIDATION_INDEX=$((VALIDATION_INDEX + 1))
}

# @description Extract app names from VALIDATION_RESULTS JSON array by status
# @arg $1 nameref to VALIDATION_RESULTS array (read-only)
# @arg $2 status filter ("success" or "error")
# @arg $3 nameref to output array (write)
extract_apps_by_status() {
  local -n results_ref=$1
  local status_filter="$2"
  local -n output_ref=$3

  mapfile -d '' -t output_ref < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr "select(.status == \"$status_filter\") | (.app, \"\\u0000\")" \
      | tr -d '\r'
  )
}

# @description Extract versions from VALIDATION_RESULTS JSON array by status
# @arg $1 nameref to VALIDATION_RESULTS array (read-only)
# @arg $2 status filter ("success" or "error")
# @arg $3 nameref to output array (write)
extract_versions_by_status() {
  local -n results_ref=$1
  local status_filter="$2"
  local -n output_ref=$3

  mapfile -d '' -t output_ref < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr "select(.status == \"$status_filter\") | (.version, \"\\u0000\")" \
      | tr -d '\r'
  )
}

# @description Handle validation error with fail-fast or error collection
# @arg $1 string Command name
# @arg $2 string Application name
# @arg $3 string Version string (empty if version unavailable)
# @arg $4 string Error message
# @exitcode 1 In fail-fast mode (exits script)
# @exitcode 0 In error collection mode (continues)
# @global FAIL_FAST boolean Whether to exit immediately on error
# @global VALIDATION_ERRORS associative array [app_name]=error_message
# @global GITHUB_OUTPUT_FILE string Path to GitHub Actions output file
handle_validation_error() {
  local cmd="$1"
  local app_name="$2"
  local version="$3"
  local error_message="$4"

  # Store error as JSON (parallel storage)
  add_validation_result "$cmd" "$app_name" "error" "$version" "$error_message"

  if [ "$FAIL_FAST" = "true" ]; then
    echo "::error::${error_message}" >&2
    {
      echo "status=error"
      echo "message=${error_message}"
      echo "failed_apps=${app_name}"
    } >> "$(get_github_output_file)"
    return 1  # Return error code instead of exit (caller will exit)
  fi
}

# @description Initialize apps list from defaults and stdin with validation
# @arg $@ array Default app definitions (cmd|app_name|version_extractor|min_version)
# @stdin Optional newline-separated app definitions (supports comments)
#        - Lines starting with # are ignored (comments)
#        - Inline comments (# and everything after) are removed
#        - Leading/trailing whitespace is stripped
#        - Empty lines are skipped
# @set APPS array Populated with validated app definitions
# @exitcode 0 Success (all apps have valid format)
# @exitcode 1 Validation failed (invalid field count in app definition)
# @stderr Error messages for invalid formats (::error:: prefix)
initialize_apps_list() {
  local -a default_apps=("$@")

  # Clear and rebuild APPS array
  APPS=()

  # Add default apps first (with validation for defense-in-depth)
  for app in "${default_apps[@]}"; do
    if ! validate_app_line "$app"; then
      return 1  # Fail-fast on validation error
    fi
    APPS+=("$app")
  done

  # Read and validate stdin apps
  if [ ! -t 0 ]; then
    local line
    # Use timeout on first read to prevent hanging, then read remaining lines
    if read -t 0.1 -r line 2>/dev/null; then
      # Process first line and all remaining lines in unified loop
      while true; do
        # 1. Remove inline comments (everything from # onwards)
        line="${line%%#*}"

        # 2. Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"  # Remove leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Remove trailing whitespace

        # 3. Skip empty lines (after comment removal and whitespace stripping)
        if [ -n "$line" ]; then
          # Validate line (format + control characters)
          if ! validate_app_line "$line"; then
            return 1  # Fail-fast on validation error
          fi

          APPS+=("$line")
        fi

        # Read next line (no timeout needed after first read)
        IFS= read -r line || break
      done
    fi
  fi

  return 0
}

# @description Output validation success to GITHUB_OUTPUT
# @arg $1 nameref to VALIDATED_APPS array (read-only)
# @arg $2 nameref to VALIDATED_VERSIONS array (read-only)
# @exitcode 0 Always returns success
# @set GITHUB_OUTPUT Writes status=success, message, validated_apps, validated_count, failed_count=0, results_json
# @description Output validation success to GITHUB_OUTPUT using JSON array
# @arg $1 nameref to VALIDATION_RESULTS array (read-only)
# @exitcode 0 Always returns success
# @set GITHUB_OUTPUT Writes status=success, message, validated_apps, validated_count, failed_count=0
output_validation_success_json() {
  local -n results_ref=$1

  # Extract successful validations from JSON array using jq pipeline
  # Pattern: Array expansion → jq filter → mapfile (functional approach)
  # Note: Use null-terminated strings to handle newlines in values
  # Note: tr -d '\r' strips Windows CRLF to match Unix LF format
  declare -a validated_apps_from_json=()
  mapfile -d '' -t validated_apps_from_json < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr 'select(.status == "success") | (.app, "\u0000")' \
      | tr -d '\r'
  )

  declare -a validated_versions_from_json=()
  mapfile -d '' -t validated_versions_from_json < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr 'select(.status == "success") | (.version, "\u0000")' \
      | tr -d '\r'
  )

  # Control character validation removed (already validated in add_validation_result)
  # Data integrity guaranteed by upstream validation layers:
  #   1. initialize_apps_list() - rejects control chars in stdin input
  #   2. add_validation_result() - final safety check before JSON storage

  # Build summary with 2-space indentation (matching output_validation_success format)
  declare -a summary_parts=()
  for i in "${!validated_apps_from_json[@]}"; do
    summary_parts+=("  ${validated_apps_from_json[$i]} ${validated_versions_from_json[$i]}")
  done

  # Format summary using printf (no IFS manipulation)
  local all_versions
  all_versions=$(printf '%s\n' "${summary_parts[@]}")

  echo "=== Application validation passed ===" >&2

  # Machine-readable output for GitHub Actions (identical format to output_validation_success)
  {
    echo "status=success"
    cat <<EOF
message<<MULTILINE_EOF
Applications validated:
${all_versions}
MULTILINE_EOF
EOF
    ( IFS=','; echo "validated_apps=${validated_apps_from_json[*]}" )
    echo "validated_count=${#validated_apps_from_json[@]}"
    echo "failed_count=0"
  } >> "$(get_github_output_file)"

  return 0
}

# @description Output validation errors from JSON array (JSON-based version)
# @arg $1 nameref VALIDATION_RESULTS array Array of JSON strings from add_validation_result
# @exitcode 1 Always returns failure (called when errors exist)
# @stderr Error summary with ::error:: prefixes
# @stdout None (outputs to GITHUB_OUTPUT_FILE)
# @see add_validation_result() for JSON structure
output_validation_errors_json() {
  local -n results_ref=$1

  # Functional approach: Array expansion → jq filter → mapfile
  # Extract failed apps in single pass using pipeline composition
  # Note: Use null-terminated strings to handle newlines in values
  declare -a failed_apps=()
  mapfile -d '' -t failed_apps < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr 'select(.status == "error") | (.app, "\u0000")'
  )

  # Extract error messages in single pass using pipeline composition
  # Note: Use null-terminated strings to handle newlines in values
  declare -a error_messages=()
  mapfile -d '' -t error_messages < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -jr 'select(.status == "error") | (.message, "\u0000")'
  )

  # Calculate error count from filtered arrays
  local error_count=${#failed_apps[@]}

  # Control character validation removed (already validated in add_validation_result)
  # Data integrity guaranteed by upstream validation layers:
  #   1. initialize_apps_list() - rejects control chars in stdin input
  #   2. add_validation_result() - final safety check before JSON storage

  # Output header to stderr
  echo "=== Application validation failed ===" >&2
  echo "::error::Application validation failed with ${error_count} error(s):" >&2

  # Output each error to stderr using printf (functional-style transformation)
  printf '::error::  - %s\n' "${error_messages[@]}" >&2

  # Format error summary with indentation using printf transformation
  local error_summary
  error_summary=$(printf '  %s\n' "${error_messages[@]}")

  # Calculate validated count from JSON (count successful validations)
  local validated_count
<<<<<<< HEAD
  validated_count=$(printf '%s\n' "${results_ref[@]}" | jq -r 'select(.status == "success")' | wc -l)
||||||| parent of 7c6aee3 (feat(validate-apps): migrate to JSON-based validation and harden command checks)
=======
  validated_count=$(printf '%s\n' "${results_ref[@]}" | jq -c 'select(.status == "success")' | wc -l)
>>>>>>> 7c6aee3 (feat(validate-apps): migrate to JSON-based validation and harden command checks)

  # Machine-readable output for GitHub Actions
  {
    echo "status=error"
    cat <<EOF
message<<MULTILINE_EOF
Application validation failed:
${error_summary}
MULTILINE_EOF
EOF
    ( IFS=','; echo "failed_apps=${failed_apps[*]}" )
    echo "failed_count=${#failed_apps[@]}"
    echo "validated_count=${validated_count}"
<<<<<<< HEAD
  } >> "$GITHUB_OUTPUT_FILE"
||||||| parent of 7c6aee3 (feat(validate-apps): migrate to JSON-based validation and harden command checks)
    ( IFS=','; echo "failed_apps=${FAILED_APPS[*]}" )
    echo "failed_count=${#FAILED_APPS[@]}"
    echo "validated_count=${#validated_ref[@]}"
  } >> "$GITHUB_OUTPUT_FILE"
=======
  } >> "$(get_github_output_file)"
>>>>>>> 7c6aee3 (feat(validate-apps): migrate to JSON-based validation and harden command checks)

  return 1
}

# @description Validate applications from list (main validation loop)
# @arg $@ array Application definitions (cmd|app_name|version_extractor|min_version)
# @exitcode 0 All applications validated successfully
# @exitcode 1 One or more applications failed validation (fail-fast mode)
# @set VALIDATED_APPS Array of validated application names
# @set VALIDATED_VERSIONS Array of validated version strings
# @set VALIDATION_ERRORS Array of error messages (if FAIL_FAST=false)
# @set GITHUB_OUTPUT Writes status, message, validated_apps, validated_count, etc.
validate_apps() {
  local -a app_list=("$@")

  for app_def in "${app_list[@]}"; do
    # Parse app definition first to get app_name for error handling
    # Supported formats: 2-field (cmd|app_name) or 4-field (cmd|app_name|extractor|version)
    local cmd app_name version_extractor min_ver
    IFS='|' read -r cmd app_name version_extractor min_ver <<EOF
$app_def
EOF

    # Extract version string early (for structured data consistency)
    # Note: Executed before validation for data alignment with cmd/app_name/etc.
    local version=""
    if command -v "$cmd" &> /dev/null 2>&1; then
      version=$("$cmd" --version 2>&1 | head -1)
    fi

    # Validate format: must be 2-field (cmd|app_name) or 4-field (cmd|app_name|extractor|version)
    local format_output format_exit_code format_status_line format_status format_message
    format_output=$(validate_app_format "$app_def")
    format_exit_code=$?
    format_status_line=$(echo "$format_output" | head -1)
    format_status="${format_status_line%%:*}"
    format_message="${format_status_line#*:}"

    if [ $format_exit_code -ne 0 ] || [ "$format_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$version" "$format_message" || return 1
      continue
    fi

    # Validate application exists (includes security check)
    local exists_output exists_exit_code exists_status_line exists_status exists_message
    exists_output=$(validate_app_exists "$cmd" "$app_name")
    exists_exit_code=$?
    exists_status_line=$(echo "$exists_output" | head -1)
    exists_status="${exists_status_line%%:*}"
    exists_message="${exists_status_line#*:}"

    if [ $exists_exit_code -ne 0 ] || [ "$exists_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$version" "$exists_message" || return 1
      continue
    fi

    # Validate application version
    local version_output version_exit_code version_status_line version_status version_message
    version_output=$(validate_app_version "$cmd" "$app_name" "$version_extractor" "$min_ver")
    version_exit_code=$?
    version_status_line=$(echo "$version_output" | head -1)
    version_status="${version_status_line%%:*}"
    version_message="${version_status_line#*:}"

    if [ $version_exit_code -ne 0 ] || [ "$version_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$version" "$version_message" || return 1
      continue
    elif [ "$version_status" = "WARNING" ]; then
      # WARNING status - log but continue
      echo "::warning::${version_message}" >&2
    fi

    # Perform tool-specific validation checks (e.g., gh auth check)
    local special_output special_exit_code special_status_line special_status special_message
    special_output=$(validate_app_special "$cmd" "$app_name")
    special_exit_code=$?
    special_status_line=$(echo "$special_output" | head -1)
    special_status="${special_status_line%%:*}"
    special_message="${special_status_line#*:}"

    if [ $special_exit_code -ne 0 ] || [ "$special_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$version" "$special_message" || return 1
      continue
    fi

    # Store app name and version separately (structured data)
    # Note: Stored after all validations pass to ensure data integrity
    # Store validation result as JSON
    add_validation_result "$cmd" "$app_name" "success" "$version" "-"
  done
}

# @description Main execution function
# @noargs
# @exitcode 0 All validations passed
# @exitcode 1 One or more validations failed
main() {
  echo "=== Validating Required Applications ==="
  echo ""

  # First: check jq availability (required for JSON processing)
  check_jq || exit 1


  # Default application definitions: cmd|app_name|version_extractor|min_version
  # Format: "command|app_name|version_extractor|min_version"
  # - command: The command to check (e.g., "git", "curl")
  # - app_name: Display name for the application (e.g., "Git", "curl")
  # - version_extractor: Safe extraction method (NO EVAL):
  #     * field:N = Extract Nth field (space-delimited, 1-indexed)
  #     * regex:PATTERN = sed -E regex with capture group (\1)
  #     * Empty string = auto-extract semver (X.Y or X.Y.Z)
  # - min_version: Minimum required version (triggers ERROR and exit 1 if lower)
  #     * Empty string = skip version check
  #
  # Delimiter: | (pipe) to avoid conflicts with regex patterns
  #
  # Examples:
  #   "git|Git|field:3|2.30"                              - Extract 3rd field, check min 2.30
  #   "curl|curl||"                                       - No version check (both empty)
  #   "gh|gh|regex:version ([0-9.]+)|2.0"                 - sed regex with capture group
  #   "node|Node.js|regex:v([0-9.]+)|18.0"                - Extract after 'v' prefix
  #
  # Security advantages:
  #   - NO eval usage - prevents arbitrary code execution
  #   - sed only - safe and standard
  #   - Prefix-typed extractors (field:/regex:) - explicit and auditable
  #   - Pipe delimiter - no conflict with regex patterns or colons
  declare -a default_apps=(
    "git|Git|field:3|2.30"                   # Extract 3rd field, check min 2.30
    "curl|curl||"                            # No version check
  )

  # Build apps list from defaults + stdin (with format validation)
  # stdin is used for additional-apps input in action.yml
  # Sets global APPS array
  if ! initialize_apps_list "${default_apps[@]}"; then
    echo "::error::Failed to build apps list from defaults/stdin" >&2
    exit 1
  fi

  # Validate all applications (populates VALIDATION_RESULTS array via add_validation_result)
  if ! validate_apps "${APPS[@]}"; then
    output_validation_errors_json VALIDATION_RESULTS
    exit 1
  fi

  # Output success (JSON-based)
  output_validation_success_json VALIDATION_RESULTS

  exit 0
||||||| parent of 21754f4 (feat(actions/validate-environment): アプリケーション検証スクリプトの実装を完成)
=======
# Safe output file handling - fallback to /dev/null if not in GitHub Actions
GITHUB_OUTPUT_FILE="${GITHUB_OUTPUT:-/dev/null}"

# Fail-fast mode: INTERNAL ONLY (not exposed as action input)
# This action is a gate - errors mean the workflow cannot continue
# Always defaults to true (fail on first error)
FAIL_FAST="${FAIL_FAST:-true}"

# Error tracking (used only when FAIL_FAST=false for internal testing/debugging)
# Changed to associative array: key=app_name, value=error_message
declare -A VALIDATION_ERRORS=()

# Applications to validate (populated by initialize_apps_list function)
declare -a APPS=()

# Validated applications (populated by validate_apps function)
declare -a VALIDATED_APPS=()        # Application names only
declare -a VALIDATED_VERSIONS=()    # Version strings only

# Parallel JSON storage (new - coexists with arrays above)
declare -a VALIDATION_RESULTS=()    # Array of JSON strings
VALIDATION_INDEX=0                  # Sequential index counter

# Extract version number from full version string
# Parameters: $1=full_version (e.g., "git version 2.52.0"), $2=version_extractor
# Output format:
#   Line 1: Extracted version number on success, "ERROR" on failure
#   Line 2+: Log messages (::error::, ::warning::, etc.)
# Exit code: 0=success, 1=failure
# Note: Safe extraction using sed only - no eval, prefix-typed extractors only
#
# Supported formats (prefix-typed):
#   field:N         - Extract Nth field (space-delimited, 1-indexed)
#   regex:PATTERN   - sed -E 's/PATTERN/\1/' with capture group
#   (empty)         - Default: extract semver (X.Y or X.Y.Z)
#
# Examples:
#   extract_version_number "git version 2.52.0" "field:3"
#   → 2.52.0
#
#   extract_version_number "unknown" ""
#   → ERROR
#   → ::error::No semver pattern found in: unknown
extract_version_number() {
  local full_version="$1"
  local version_extractor="$2"

  # Default: extract semver (X.Y or X.Y.Z) if extractor is empty
  if [ -z "$version_extractor" ]; then
    local extracted
    extracted=$(echo "$full_version" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

    if [ -z "$extracted" ]; then
      echo "ERROR"
      echo "::error::No semver pattern found in: $full_version"
      return 1
    fi

    echo "$extracted"
    return 0
  fi

  # Parse extractor format: method:argument
  local method="${version_extractor%%:*}"
  local argument="${version_extractor#*:}"

  case "$method" in
    field)
      # Extract Nth field (space-delimited)
      if [[ ! "$argument" =~ ^[0-9]+$ ]]; then
        echo "ERROR"
        echo "::error::Invalid field number: $argument"
        return 1
      fi
      local result
      result=$(echo "$full_version" | cut -d' ' -f"$argument")
      echo "$result"
      return 0
      ;;

    regex)
      # Extract using sed -E regex with capture group
      # Use # delimiter to allow / in regex patterns
      if [ -z "$argument" ]; then
        echo "ERROR"
        echo "::error::Empty regex pattern"
        return 1
      fi

      # Security: Validate regex pattern to prevent injection
      # Reject our delimiter (#) to prevent breaking out of sed pattern
      if [[ "$argument" == *"#"* ]]; then
        echo "ERROR"
        echo "::error::Regex pattern cannot contain '#' character (reserved as sed delimiter)"
        return 1
      fi

      # Reject shell metacharacters that shouldn't appear in version extraction regex
      if [[ "$argument" =~ [\;\|\&\$\`\\] ]]; then
        echo "ERROR"
        echo "::error::Regex pattern contains dangerous shell metacharacters: $argument"
        return 1
      fi

      # Reject newlines and control characters
      if [[ "$argument" =~ $'\n'|$'\r'|$'\t' ]]; then
        echo "ERROR"
        echo "::error::Regex pattern contains control characters"
        return 1
      fi

      # Wrap pattern with .* for full line matching if not already present
      local sed_pattern="$argument"
      if [[ ! "$sed_pattern" =~ ^\.\* ]]; then
        sed_pattern=".*${sed_pattern}"
      fi
      if [[ ! "$sed_pattern" =~ \.\*$ ]]; then
        sed_pattern="${sed_pattern}.*"
      fi

      local extracted
      extracted=$(echo "$full_version" | sed -E "s#${sed_pattern}#\1#")

      # Check if extraction succeeded (result differs from input)
      if [ "$extracted" = "$full_version" ]; then
        echo "ERROR"
        echo "::error::Pattern did not match: $argument"
        return 1
      fi

      echo "$extracted"
      return 0
      ;;

    *)
      echo "ERROR"
      echo "::error::Unknown extraction method: $method (expected: field, regex, or empty)"
      return 1
      ;;
  esac
}

# Check version meets minimum requirement (pure comparison function)
# Parameters: $1=version (e.g., "2.52.0"), $2=min_version (e.g., "2.30")
# Output format:
#   Line 1: "SUCCESS" if version >= min_version, "FAILURE" if version < min_version
#   Line 2+: Log messages (optional)
# Exit code: 0=success, 1=failure
# Note: Uses sort -V for stable version comparison (handles semver, prerelease, etc.)
#       Requires GNU coreutils (available on all GitHub-hosted runners)
check_version() {
  local version="$1"
  local min_version="$2"

  # Use sort -V (version sort) to compare
  # If min_version comes first or equal, version meets requirement
  # printf outputs: min_version, version (in that order)
  # sort -V sorts them in version order
  # If first line after sort == min_version, then version >= min_version
  local sorted_min=$(printf '%s\n%s\n' "$min_version" "$version" | sort -V | head -1)

  if [ "$sorted_min" = "$min_version" ]; then
    echo "SUCCESS"
    return 0  # version >= min_version
  else
    echo "FAILURE"
    return 1  # version < min_version
  fi
}

# @description Get application version string
# @arg $1 string Command name
# @exitcode 0 Version retrieved successfully
# @exitcode 1 Command failed or version unavailable
# @stdout Full version string (e.g., "git version 2.52.0")
get_app_version() {
  local cmd="$1"

  # Get full version string
  local version_output
  if ! version_output=$("$cmd" --version 2>&1 | head -1); then
    return 1
  fi

  # Output version string to stdout
  echo "$version_output"
  return 0
}

# @description Check GitHub CLI authentication status
# @exitcode 0 gh is authenticated
# @exitcode 1 gh is not authenticated or authentication check failed
check_gh_authentication() {
  # Check authentication status using gh auth status
  # Exit code 0 = authenticated, 1 = not authenticated or auth issues
  gh auth status >/dev/null 2>&1
  return $?
}

# @description Validate application exists and command name is safe
# @arg $1 string Command name
# @arg $2 string Application display name
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Command is valid and exists
# @exitcode 1 Failed (command not found or invalid name)
validate_app_exists() {
  local cmd="$1"
  local app_name="$2"

  # Security: Validate command name (reject shell metacharacters)
  # This prevents command injection via malicious app definitions
  #
  # Rejected: ; | & $ ` ( ) space tab (common injection vectors)
  # Intentionally allowed: / . - _ (for paths like /usr/bin/gh or ./bin/tool)
  # Design: Balance security with practicality for legitimate command names
  if [[ "$cmd" =~  [\;\|\&\$\`\(\)[:space:]] ]]; then
    echo "ERROR:Invalid command name contains shell metacharacters: $cmd"
    echo "::error::Invalid command name contains shell metacharacters: $cmd" >&2
    return 1
  fi

  echo "Checking ${app_name}..." >&2

  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR:${app_name} is not installed"
    echo "::error::${app_name} is not installed" >&2
    return 1
  fi

  echo "SUCCESS:${app_name} command found"
  return 0
}

# @description Validate application version
# @arg $1 string Command name
# @arg $2 string Application display name
# @arg $3 string Version extractor (field:N, regex:PATTERN, or empty)
# @arg $4 string Minimum required version (empty = skip check)
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/WARNING/ERROR, message is detail
# @exitcode 0 Version meets requirements
# @exitcode 1 Failed (extraction error or version too low)
validate_app_version() {
  local cmd="$1"
  local app_name="$2"
  local version_extractor="$3"
  local min_ver="$4"

  # Get full version string using helper function
  local version_string
  if ! version_string=$(get_app_version "$cmd"); then
    echo "ERROR:Failed to get version for ${app_name}"
    echo "::error::Failed to get version for ${app_name}" >&2
    return 1
  fi

  echo "  ✓ ${version_string}" >&2
  echo "" >&2

  # Check minimum version if min_ver is specified
  if [ -n "$min_ver" ]; then
    # Extract version number from full version string
    local extract_output version_num log_lines
    extract_output=$(extract_version_number "$version_string" "$version_extractor")
    local extract_status=$?

    version_num=$(echo "$extract_output" | head -1)
    log_lines=$(echo "$extract_output" | tail -n +2)

    if [ $extract_status -ne 0 ] || [ "$version_num" = "ERROR" ]; then
      echo "ERROR:Version extraction failed for ${app_name}"
      if [ -n "$log_lines" ]; then
        echo "$log_lines" >&2
      fi
      return 1
    fi

    # Validate version against minimum requirement
    local check_output check_result
    check_output=$(check_version "$version_num" "$min_ver")
    local check_status=$?
    check_result=$(echo "$check_output" | head -1)

    if [ $check_status -ne 0 ] || [ "$check_result" = "FAILURE" ]; then
      echo "ERROR:${app_name} version ${version_num} is below minimum required ${min_ver}"
      echo "::error::${app_name} version ${version_num} is below minimum required ${min_ver}" >&2
      return 1
    fi

    echo "SUCCESS:${app_name} version ${version_num} meets minimum ${min_ver}"
    return 0
  fi

  # Version check skipped - return warning
  echo "WARNING:${app_name} version check skipped (no minimum version specified)"
  echo "  ::warning::${app_name}: version check skipped (no minimum version specified)" >&2
  return 0
}

# @description Perform tool-specific validation checks (e.g., gh auth check)
# @arg $1 string Command name
# @arg $2 string Application display name
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Validation passed or no special check needed
# @exitcode 1 Validation failed
# @stderr Log messages (::error::, info)
validate_app_special() {
  local cmd="$1"
  local app_name="$2"

  case "$cmd" in
    gh)
      # GitHub CLI: Check authentication status
      echo "Checking ${app_name} authentication..." >&2

      if ! check_gh_authentication; then
        echo "ERROR:${app_name} is not authenticated"
        echo "::error::${app_name} is not authenticated. Run 'gh auth login' to authenticate." >&2
        return 1
      fi

      echo "  ✓ ${app_name} is authenticated" >&2
      echo "" >&2
      echo "SUCCESS:${app_name} is authenticated"
      return 0
      ;;

    # Future extension points:
    #
    # docker)
    #   # Docker: Check daemon is running
    #   echo "Checking ${app_name} daemon..." >&2
    #   if ! docker info >/dev/null 2>&1; then
    #     echo "ERROR:Docker daemon is not running"
    #     echo "::error::Docker daemon is not running. Start Docker Desktop or dockerd." >&2
    #     return 1
    #   fi
    #   echo "  ✓ ${app_name} daemon is running" >&2
    #   echo "" >&2
    #   echo "SUCCESS:${app_name} daemon is running"
    #   return 0
    #   ;;
    #
    # aws)
    #   # AWS CLI: Check credentials are configured
    #   echo "Checking ${app_name} credentials..." >&2
    #   if ! aws sts get-caller-identity >/dev/null 2>&1; then
    #     echo "ERROR:AWS credentials not configured"
    #     echo "::error::AWS credentials not configured. Run 'aws configure'." >&2
    #     return 1
    #   fi
    #   echo "  ✓ ${app_name} credentials configured" >&2
    #   echo "" >&2
    #   echo "SUCCESS:${app_name} credentials configured"
    #   return 0
    #   ;;

    *)
      # No special validation needed for this command
      echo "SUCCESS:No special validation required"
      return 0
      ;;
  esac
}

# @description Validate app definition format (field count only)
# @arg $1 string App definition line (cmd|app_name|version_extractor|min_version)
# @stdout Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Valid format (SUCCESS)
# @exitcode 1 Invalid format (ERROR)
validate_app_format() {
  local line="$1"

  # Count pipe delimiters to determine field count
  local field_count
  field_count=$(echo "$line" | grep -o '|' | wc -l)
  field_count=$((field_count + 1))  # fields = delimiters + 1

  # Validate field count: must be exactly 2 or 4
  if [ "$field_count" -ne 2 ] && [ "$field_count" -ne 4 ]; then
    echo "ERROR:Invalid app definition format (expected 2 or 4 fields, got ${field_count})"
    echo "::error::Invalid app definition format (expected 2 or 4 pipe-delimited fields, got ${field_count}): $line" >&2
    return 1
  fi

  echo "SUCCESS:Valid app definition format"
  return 0
}

# @description Add validation result to JSON array (unified storage)
# @arg $1 string Command name
# @arg $2 string Application name
# @arg $3 string Status (success|error)
# @arg $4 string Version string (empty for errors)
# @arg $5 string Error message (empty for success)
# @global VALIDATION_RESULTS array JSON storage
# @global VALIDATION_INDEX number Sequential index counter
add_validation_result() {
  local cmd="$1"
  local app_name="$2"
  local status="$3"
  local version="$4"
  local message="$5"

  local result_json
  if [ "$status" = "error" ]; then
    result_json=$(jq -n \
      --arg index "$VALIDATION_INDEX" \
      --arg cmd "$cmd" \
      --arg app "$app_name" \
      --arg status "$status" \
      --arg version "$version" \
      --arg message "$message" \
      '{index: ($index | tonumber), cmd: $cmd, app: $app, status: $status, version: $version, message: $message}')
  else
    result_json=$(jq -n \
      --arg index "$VALIDATION_INDEX" \
      --arg cmd "$cmd" \
      --arg app "$app_name" \
      --arg status "$status" \
      --arg version "$version" \
      '{index: ($index | tonumber), cmd: $cmd, app: $app, status: $status, version: $version}')
  fi

  VALIDATION_RESULTS+=("$result_json")
  VALIDATION_INDEX=$((VALIDATION_INDEX + 1))
}

# @description Handle validation error with fail-fast or error collection
# @arg $1 string Command name
# @arg $2 string Application name
# @arg $3 string Version string (empty if version unavailable)
# @arg $4 string Error message
# @exitcode 1 In fail-fast mode (exits script)
# @exitcode 0 In error collection mode (continues)
# @global FAIL_FAST boolean Whether to exit immediately on error
# @global VALIDATION_ERRORS associative array [app_name]=error_message
# @global GITHUB_OUTPUT_FILE string Path to GitHub Actions output file
handle_validation_error() {
  local cmd="$1"
  local app_name="$2"
  local version="$3"
  local error_message="$4"

  # Store error as JSON (parallel storage)
  add_validation_result "$cmd" "$app_name" "error" "$version" "$error_message"

  if [ "$FAIL_FAST" = "true" ]; then
    echo "::error::${error_message}" >&2
    {
      echo "status=error"
      echo "message=${error_message}"
      echo "failed_apps=${app_name}"
    } >> "$GITHUB_OUTPUT_FILE"
    return 1  # Return error code instead of exit (caller will exit)
  else
    VALIDATION_ERRORS["$app_name"]="$error_message"
    return 0
  fi
}

# @description Initialize apps list from defaults and stdin with validation
# @arg $@ array Default app definitions (cmd|app_name|version_extractor|min_version)
# @stdin Optional newline-separated app definitions (supports comments)
#        - Lines starting with # are ignored (comments)
#        - Inline comments (# and everything after) are removed
#        - Leading/trailing whitespace is stripped
#        - Empty lines are skipped
# @set APPS array Populated with validated app definitions
# @exitcode 0 Success (all apps have valid format)
# @exitcode 1 Validation failed (invalid field count in app definition)
# @stderr Error messages for invalid formats (::error:: prefix)
initialize_apps_list() {
  local -a default_apps=("$@")

  # Clear and rebuild APPS array
  APPS=()

  # Add default apps first (no validation needed - trusted internal data)
  for app in "${default_apps[@]}"; do
    APPS+=("$app")
  done

  # Read and validate stdin apps
  if [ ! -t 0 ]; then
    local line
    # Use timeout on first read to prevent hanging, then read remaining lines
    if read -t 0.1 -r line 2>/dev/null; then
      # Process first line and all remaining lines in unified loop
      while true; do
        # 1. Remove inline comments (everything from # onwards)
        line="${line%%#*}"

        # 2. Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"  # Remove leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # Remove trailing whitespace

        # 3. Skip empty lines (after comment removal and whitespace stripping)
        if [ -n "$line" ]; then
          # Validate format and capture output
          local format_output format_exit_code format_status_line format_status format_message
          format_output=$(validate_app_format "$line")
          format_exit_code=$?
          format_status_line=$(echo "$format_output" | head -1)
          format_status="${format_status_line%%:*}"
          format_message="${format_status_line#*:}"

          if [ "$format_exit_code" -ne 0 ] || [ "$format_status" = "ERROR" ]; then
            echo "::error::${format_message}" >&2
            return 1  # Fail-fast on validation error
          fi

          APPS+=("$line")
        fi

        # Read next line (no timeout needed after first read)
        IFS= read -r line || break
      done
    fi
  fi

  return 0
}

# @description Output validation success to GITHUB_OUTPUT
# @arg $1 nameref to VALIDATED_APPS array (read-only)
# @arg $2 nameref to VALIDATED_VERSIONS array (read-only)
# @exitcode 0 Always returns success
# @set GITHUB_OUTPUT Writes status=success, message, validated_apps, validated_count, failed_count=0, results_json
output_validation_success() {
  local -n validated_apps_ref=$1
  local -n validated_versions_ref=$2

  # Build summary with 2-space indentation
  declare -a summary_parts=()
  for i in "${!validated_apps_ref[@]}"; do
    summary_parts+=("  ${validated_apps_ref[$i]} ${validated_versions_ref[$i]}")
  done

  # Format summary using printf (no IFS manipulation)
  local all_versions
  all_versions=$(printf '%s\n' "${summary_parts[@]}")

  echo "=== Application validation passed ===" >&2

  # Machine-readable output for GitHub Actions
  {
    echo "status=success"
    cat <<EOF
message<<MULTILINE_EOF
Applications validated:
${all_versions}
MULTILINE_EOF
EOF
    ( IFS=','; echo "validated_apps=${validated_apps_ref[*]}" )
    echo "validated_count=${#validated_apps_ref[@]}"
    echo "failed_count=0"
  } >> "$GITHUB_OUTPUT_FILE"

  return 0
}

# @description Output validation errors to GITHUB_OUTPUT and stderr
# @arg $1 nameref to VALIDATION_ERRORS associative array [app_name]=error_message (read-only)
# @arg $2 nameref to VALIDATED_APPS array (read-only)
# @exitcode 1 Always returns failure (called when validation failed)
# @stderr Error messages with ::error:: prefix
# @set GITHUB_OUTPUT Writes status=error, message, failed_apps, failed_count, validated_count
output_validation_errors() {
  local -n errors_ref=$1
  local -n validated_ref=$2

  # Build arrays from associative array using functional-style mapping
  declare -a FAILED_APPS=()
  declare -a error_messages=()

  for app_name in "${!errors_ref[@]}"; do
    FAILED_APPS+=("$app_name")
    error_messages+=("${errors_ref[$app_name]}")
  done

  # Output header to stderr
  echo "=== Application validation failed ===" >&2
  echo "::error::Application validation failed with ${#errors_ref[@]} error(s):" >&2

  # Output each error to stderr using printf (functional-style transformation)
  printf '::error::  - %s\n' "${error_messages[@]}" >&2

  # Format error summary with indentation using printf transformation
  local error_summary
  error_summary=$(printf '  %s\n' "${error_messages[@]}")

  # Machine-readable output for GitHub Actions
  {
    echo "status=error"
    cat <<EOF
message<<MULTILINE_EOF
Application validation failed:
${error_summary}
MULTILINE_EOF
EOF
    ( IFS=','; echo "failed_apps=${FAILED_APPS[*]}" )
    echo "failed_count=${#FAILED_APPS[@]}"
    echo "validated_count=${#validated_ref[@]}"
  } >> "$GITHUB_OUTPUT_FILE"

  return 1
}

# @description Output validation errors from JSON array (JSON-based version)
# @arg $1 nameref VALIDATION_RESULTS array Array of JSON strings from add_validation_result
# @arg $2 nameref VALIDATED_APPS array Array of validated application names
# @exitcode 1 Always returns failure (called when errors exist)
# @stderr Error summary with ::error:: prefixes
# @stdout None (outputs to GITHUB_OUTPUT_FILE)
# @see add_validation_result() for JSON structure
output_validation_errors_json() {
  local -n results_ref=$1
  local -n validated_ref=$2

  # Functional approach: Array expansion → jq filter → mapfile
  # Extract failed apps in single pass using pipeline composition
  declare -a FAILED_APPS=()
  mapfile -t FAILED_APPS < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -r 'select(.status == "error") | .app'
  )

  # Extract error messages in single pass using pipeline composition
  declare -a error_messages=()
  mapfile -t error_messages < <(
    printf '%s\n' "${results_ref[@]}" \
      | jq -r 'select(.status == "error") | .message'
  )

  # Calculate error count from filtered arrays
  local error_count=${#FAILED_APPS[@]}

  # Output header to stderr
  echo "=== Application validation failed ===" >&2
  echo "::error::Application validation failed with ${error_count} error(s):" >&2

  # Output each error to stderr using printf (functional-style transformation)
  printf '::error::  - %s\n' "${error_messages[@]}" >&2

  # Format error summary with indentation using printf transformation
  local error_summary
  error_summary=$(printf '  %s\n' "${error_messages[@]}")

  # Machine-readable output for GitHub Actions
  {
    echo "status=error"
    cat <<EOF
message<<MULTILINE_EOF
Application validation failed:
${error_summary}
MULTILINE_EOF
EOF
    ( IFS=','; echo "failed_apps=${FAILED_APPS[*]}" )
    echo "failed_count=${#FAILED_APPS[@]}"
    echo "validated_count=${#validated_ref[@]}"
  } >> "$GITHUB_OUTPUT_FILE"

  return 1
}

# @description Validate applications from list (main validation loop)
# @arg $@ array Application definitions (cmd|app_name|version_extractor|min_version)
# @exitcode 0 All applications validated successfully
# @exitcode 1 One or more applications failed validation (fail-fast mode)
# @set VALIDATED_APPS Array of validated application names
# @set VALIDATED_VERSIONS Array of validated version strings
# @set VALIDATION_ERRORS Array of error messages (if FAIL_FAST=false)
# @set GITHUB_OUTPUT Writes status, message, validated_apps, validated_count, etc.
validate_apps() {
  local -a app_list=("$@")

  for app_def in "${app_list[@]}"; do
    # Parse app definition first to get app_name for error handling
    # Supported formats: 2-field (cmd|app_name) or 4-field (cmd|app_name|extractor|version)
    local cmd app_name version_extractor min_ver
    IFS='|' read -r cmd app_name version_extractor min_ver <<EOF
$app_def
EOF

    # Extract version string early (for structured data consistency)
    # Note: Executed before validation for data alignment with cmd/app_name/etc.
    local VERSION=""
    if command -v "$cmd" &> /dev/null 2>&1; then
      VERSION=$("$cmd" --version 2>&1 | head -1)
    fi

    # Validate format: must be 2-field (cmd|app_name) or 4-field (cmd|app_name|extractor|version)
    local format_output format_exit_code format_status_line format_status format_message
    format_output=$(validate_app_format "$app_def")
    format_exit_code=$?
    format_status_line=$(echo "$format_output" | head -1)
    format_status="${format_status_line%%:*}"
    format_message="${format_status_line#*:}"

    if [ $format_exit_code -ne 0 ] || [ "$format_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$VERSION" "$format_message" || return 1
      continue
    fi

    # Validate application exists (includes security check)
    local exists_output exists_exit_code exists_status_line exists_status exists_message
    exists_output=$(validate_app_exists "$cmd" "$app_name")
    exists_exit_code=$?
    exists_status_line=$(echo "$exists_output" | head -1)
    exists_status="${exists_status_line%%:*}"
    exists_message="${exists_status_line#*:}"

    if [ $exists_exit_code -ne 0 ] || [ "$exists_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$VERSION" "$exists_message" || return 1
      continue
    fi

    # Validate application version
    local version_output version_exit_code version_status_line version_status version_message
    version_output=$(validate_app_version "$cmd" "$app_name" "$version_extractor" "$min_ver")
    version_exit_code=$?
    version_status_line=$(echo "$version_output" | head -1)
    version_status="${version_status_line%%:*}"
    version_message="${version_status_line#*:}"

    if [ $version_exit_code -ne 0 ] || [ "$version_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$VERSION" "$version_message" || return 1
      continue
    elif [ "$version_status" = "WARNING" ]; then
      # WARNING status - log but continue
      echo "::warning::${version_message}" >&2
    fi

    # Perform tool-specific validation checks (e.g., gh auth check)
    local special_output special_exit_code special_status_line special_status special_message
    special_output=$(validate_app_special "$cmd" "$app_name")
    special_exit_code=$?
    special_status_line=$(echo "$special_output" | head -1)
    special_status="${special_status_line%%:*}"
    special_message="${special_status_line#*:}"

    if [ $special_exit_code -ne 0 ] || [ "$special_status" = "ERROR" ]; then
      handle_validation_error "$cmd" "$app_name" "$VERSION" "$special_message" || return 1
      continue
    fi

    # Store app name and version separately (structured data)
    # Note: Stored after all validations pass to ensure data integrity
    VALIDATED_APPS+=("${app_name}")
    VALIDATED_VERSIONS+=("${VERSION}")

    # Parallel: Store as JSON (for future migration)
    add_validation_result "$cmd" "$app_name" "success" "$VERSION" "-"
  done
}

# @description Main execution function
# @noargs
# @exitcode 0 All validations passed
# @exitcode 1 One or more validations failed
main() {
  echo "=== Validating Required Applications ==="
  echo ""

# Default application definitions: cmd|app_name|version_extractor|min_version
# Format: "command|app_name|version_extractor|min_version"
# - command: The command to check (e.g., "git", "curl")
# - app_name: Display name for the application (e.g., "Git", "curl")
# - version_extractor: Safe extraction method (NO EVAL):
#     * field:N = Extract Nth field (space-delimited, 1-indexed)
#     * regex:PATTERN = sed -E regex with capture group (\1)
#     * Empty string = auto-extract semver (X.Y or X.Y.Z)
# - min_version: Minimum required version (triggers ERROR and exit 1 if lower)
#     * Empty string = skip version check
#
# Delimiter: | (pipe) to avoid conflicts with regex patterns
#
# Examples:
#   "git|Git|field:3|2.30"                              - Extract 3rd field, check min 2.30
#   "curl|curl||"                                       - No version check (both empty)
#   "gh|gh|regex:version ([0-9.]+)|2.0"                 - sed regex with capture group
#   "node|Node.js|regex:v([0-9.]+)|18.0"                - Extract after 'v' prefix
#
# Security advantages:
#   - NO eval usage - prevents arbitrary code execution
#   - sed only - safe and standard
#   - Prefix-typed extractors (field:/regex:) - explicit and auditable
#   - Pipe delimiter - no conflict with regex patterns or colons
declare -a DEFAULT_APPS=(
  "git|Git|field:3|2.30"                   # Extract 3rd field, check min 2.30
  "curl|curl||"                            # No version check
)

# Build apps list from defaults + stdin (with format validation)
# stdin is used for additional-apps input in action.yml
# Sets global APPS array
if ! initialize_apps_list "${DEFAULT_APPS[@]}"; then
  echo "::error::Failed to build apps list from defaults/stdin" >&2
  exit 1
fi

# Validate all applications (populates VALIDATED_VERSIONS and VALIDATION_ERRORS arrays)
if ! validate_apps "${APPS[@]}"; then
  exit 1
fi

# Check for collected errors (in collect-errors mode)
if [ ${#VALIDATION_ERRORS[@]} -gt 0 ]; then
  output_validation_errors VALIDATION_ERRORS VALIDATED_APPS
  exit 1
fi

# Output success
output_validation_success VALIDATED_APPS VALIDATED_VERSIONS
exit 0
>>>>>>> 21754f4 (feat(actions/validate-environment): アプリケーション検証スクリプトの実装を完成)
}

# Only run main if script is executed directly (not sourced/included)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
