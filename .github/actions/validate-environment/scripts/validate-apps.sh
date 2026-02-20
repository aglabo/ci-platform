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
# @version  0.1.0
# @license  MIT

set -euo pipefail

# ============================================================================
# Section 1: OUTPUT ABSTRACTION & GLOBALS
# ============================================================================

# @description Return GITHUB_OUTPUT path for grouped redirect
# @stdout Path to GITHUB_OUTPUT (fallback: /dev/null)
# @example { echo "status=success"; echo "message=OK"; } >> "$(out_status)"
out_status() {
  echo "${GITHUB_OUTPUT:-/dev/null}"
}

# Maximum number of apps allowed in APPS list
# Prevents resource exhaustion (DoS) from unbounded stdin input in gate action context
MAX_APPS=30

# Applications to validate (populated by initialize_apps_list function)
declare -a APPS=()

# JSON-structured validation results (populated by validate_apps)
declare -a VALIDATION_RESULTS=()
VALIDATION_INDEX=0

# ============================================================================
# Section 2: VERSION EXTRACTION FUNCTIONS
# ============================================================================

# @description Validate a regex pattern for safe use in sed ERE with # delimiter
# @arg $1 string Regex pattern to validate
# @exitcode 0 Pattern is safe to use
# @exitcode 1 Empty pattern
# @exitcode 2 Contains '#' (reserved as sed delimiter)
# @exitcode 3 Contains shell metacharacters (;|&$`)
# @exitcode 4 Contains control characters (newline/CR/tab)
# @note No output. Caller uses exit code to construct error messages.
# @note Backslashes are allowed (e.g., \. for literal dot, \( for literal parenthesis).
#       Shell injection is prevented by metacharacter checks; # delimiter prevents delimiter breaking.
is_safe_regex() {
  local pattern="$1"
  [ -z "$pattern" ] && return 1
  [[ "$pattern" == *"#"* ]] && return 2
  [[ "$pattern" =~ [\;\|\&\$\`] ]] && return 3
  [[ "$pattern" =~ $'\n'|$'\r'|$'\t' ]] && return 4
  return 0
}

# @description Extract version using regex pattern (sed-based, security hardened)
# @arg $1 string Full version string (e.g., "git version 2.52.0")
# @arg $2 string Regex pattern (without "regex:" prefix)
# Output format:
#   Line 1: Extracted version on success, "ERROR" on failure
#   Line 2+: Log messages (::error::, etc.)
# @exitcode 0 Extraction successful
# @exitcode 1 Failure (pattern did not match or invalid input)
# @note Uses sed with # delimiter to allow / in patterns
# @note Pattern security validated by is_safe_regex()
extract_version_by_regex() {
  local full_version="$1"
  local regex_pattern="$2"

  # Validate regex pattern (security + syntax checks)
  local safe_status=0
  is_safe_regex "$regex_pattern" || safe_status=$?
  case $safe_status in
    0) ;;
    1) echo "ERROR"; echo "::error::Empty regex pattern"; return 1 ;;
    2) echo "ERROR"; echo "::error::Regex pattern cannot contain '#' character (reserved as sed delimiter)"; return 1 ;;
    3) echo "ERROR"; echo "::error::Regex pattern contains dangerous shell metacharacters: $regex_pattern"; return 1 ;;
    4) echo "ERROR"; echo "::error::Regex pattern contains control characters"; return 1 ;;
    *) echo "ERROR"; echo "::error::Invalid regex pattern"; return 1 ;;
  esac

  # Wrap pattern with .* for full line matching if not already present
  local sed_pattern="$regex_pattern"
  if [[ ! "$sed_pattern" =~ ^\.\* ]]; then
    sed_pattern=".*${sed_pattern}"
  fi
  if [[ ! "$sed_pattern" =~ \.\*$ ]]; then
    sed_pattern="${sed_pattern}.*"
  fi

  # Extract using sed -E with # delimiter
  local extracted sed_exit
  extracted=$(echo "$full_version" | sed -E "s#${sed_pattern}#\1#" 2>/dev/null)
  sed_exit=$?

  # Check if sed itself failed (e.g., invalid regex such as unmatched parenthesis)
  if [ $sed_exit -ne 0 ]; then
    echo "ERROR"
    echo "::error::Invalid regex pattern (sed error): $regex_pattern"
    return 1
  fi

  # Check if extraction succeeded (result differs from input)
  if [ "$extracted" = "$full_version" ]; then
    echo "ERROR"
    echo "::error::Pattern did not match: $regex_pattern"
    return 1
  fi

  echo "$extracted"
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
      # Delegate to extract_version_by_regex helper function
      extract_version_by_regex "$full_version" "$argument"
      return $?
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

# ============================================================================
# Section 3: VALIDATION FUNCTIONS
# ============================================================================

# @description Validate app definition format and security
# @description Validate a command name for safe use in shell execution
# @arg $1 string Command name to validate
# @exitcode 0 Command name is safe
# @exitcode 1 Contains control characters (newline/CR/tab)
# @exitcode 2 Contains relative path (./ or ../)
# @exitcode 3 Contains shell metacharacters (;|&$`() space)
# @note No output. Caller uses exit code to construct error messages.
# Rejected: control characters, relative paths (./ ../), shell metacharacters (;|&$`() space)
# Allowed: / - _ (for absolute paths like /usr/bin/gh)
is_safe_command() {
  local cmd="$1"
  [[ "$cmd" =~ $'\n'|$'\r'|$'\t' ]] && return 1
  [[ "$cmd" == ./* || "$cmd" == ../* || "$cmd" == */./* || "$cmd" == */../* ]] && return 2
  [[ "$cmd" =~  [\;\|\&\$\`\(\)[:space:]] ]] && return 3
  return 0
}

# @arg $1 string App definition line (cmd|app_name|version_extractor|min_version)
# @stdout Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Valid format (SUCCESS)
# @exitcode 1 Invalid format or security violation (ERROR)
# Validates:
#   1. Field count (2 or 4 pipe-delimited fields)
#   2. Command name security (via is_safe_command)
#   3. App name security (rejects control characters)
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

  # Extract cmd and app_name fields for security validation
  # Use parameter expansion to preserve control characters
  local cmd app_name
  cmd="${line%%|*}"                    # Extract first field (everything before first |)
  local remaining="${line#*|}"         # Remove first field and delimiter
  app_name="${remaining%%|*}"          # Extract second field

  # Security: Validate command name (control characters, relative paths, metacharacters)
  local cmd_status=0
  is_safe_command "$cmd" || cmd_status=$?
  case $cmd_status in
    0) ;;
    1) echo "ERROR:Invalid command name contains control characters"
       echo "::error::Invalid command name '${cmd}': contains control characters (newline/CR/tab)" >&2
       echo "::error::This indicates malicious input or data corruption" >&2
       return 1 ;;
    2) echo "ERROR:Invalid command name contains relative path: $cmd"
       echo "::error::Invalid command name contains relative path: $cmd" >&2
       return 1 ;;
    3) echo "ERROR:Invalid command name contains shell metacharacters: $cmd"
       echo "::error::Invalid command name contains shell metacharacters: $cmd" >&2
       return 1 ;;
  esac

  # Security: Validate app_name for control characters (newline, CR, tab) - CHECK FIRST
  # This prevents log injection attacks
  # Note: Checked before other validations for more specific error messages
  if [[ "$app_name" =~ $'\n'|$'\r'|$'\t' ]]; then
    echo "ERROR:Invalid app name contains control characters"
    echo "::error::Invalid app_name '${app_name}': contains control characters (newline/CR/tab)" >&2
    echo "::error::This indicates malicious input or data corruption" >&2
    return 1
  fi

  echo "SUCCESS:Valid app definition format"
  return 0
}

# @description Validate application exists
# @arg $1 string Command name
# @arg $2 string Application display name
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/ERROR, message is detail
# @exitcode 0 Command exists
# @exitcode 1 Command not found
# Note: Security validation (metacharacters, relative paths) is handled by validate_app_format()
validate_app_exists() {
  local cmd="$1"
  local app_name="$2"

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
# @arg $5 string Optional: pre-fetched version string (avoids second get_app_version call)
# Output format:
#   Line 1: "STATUS:message" - STATUS is SUCCESS/WARNING/ERROR, message is detail
# @exitcode 0 Version meets requirements
# @exitcode 1 Failed (extraction error or version too low)
validate_app_version() {
  local cmd="$1"
  local app_name="$2"
  local version_extractor="$3"
  local min_ver="$4"
  local version_string="${5:-}"  # Optional: pre-fetched version string

  # Guard 1: Get version string (only if not pre-fetched)
  if [ -z "$version_string" ]; then
    if ! version_string=$(get_app_version "$cmd"); then
      echo "ERROR:Failed to get version for ${app_name}"
      echo "::error::Failed to get version for ${app_name}" >&2
      return 1
    fi
  fi

  echo "  ✓ ${version_string}" >&2
  echo "" >&2

  # Guard 2: Skip version check if no minimum version specified
  if [ -z "$min_ver" ]; then
    echo "WARNING:${app_name} version check skipped (no minimum version specified)"
    echo "  ::warning::${app_name}: version check skipped (no minimum version specified)" >&2
    return 0
  fi

  # Guard 3: Extract version number
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

  # Guard 4: Validate version meets minimum requirement
  if ! check_version "$version_num" "$min_ver" > /dev/null; then
    echo "ERROR:${app_name} version ${version_num} is below minimum required ${min_ver}"
    echo "::error::${app_name} version ${version_num} is below minimum required ${min_ver}" >&2
    return 1
  fi

  # Success: version meets requirements
  echo "SUCCESS:${app_name} version ${version_num} meets minimum ${min_ver}"
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
  local cmd_name
  cmd_name=$(basename "$cmd")  # Normalize: /usr/bin/gh → gh

  case "$cmd_name" in
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

    *)
      # No special validation needed for this command
      echo "SUCCESS:No special validation required"
      return 0
      ;;
  esac
}

# @description Check that jq is installed (required for JSON output)
# @exitcode 0 jq is available
# @exitcode 1 jq is not found
check_jq() {
  command -v jq >/dev/null 2>&1
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

# @description Handle validation error (fail-fast: immediate output and return 1)
# @arg $1 string Command name
# @arg $2 string Application name
# @arg $3 string Version string (empty if version unavailable)
# @arg $4 string Error message
# @exitcode 1 Always (fail-fast mode)
# @global VALIDATION_RESULTS array Count of successfully validated apps so far
# @global GITHUB_OUTPUT string Path to GitHub Actions output file
handle_validation_error() {
  local cmd="$1"
  local app_name="$2"
  local version="$3"
  local error_message="$4"

  echo "::error::${error_message}" >&2
  {
    echo "status=error"
    echo "message=${error_message}"
    echo "failed_apps=${app_name}"
    echo "failed_count=1"
    echo "validated_count=${#VALIDATION_RESULTS[@]}"
  } >> "$(out_status)"

  # Append JSON error entry to structured results array
  local json_entry
  json_entry=$(jq -n \
    --arg status "error" \
    --arg app "$app_name" \
    --arg version "$version" \
    --arg message "$error_message" \
    '{"status": $status, "app": $app, "version": $version, "message": $message}')
  VALIDATION_RESULTS+=("$json_entry")
  return 1
}

# ============================================================================
# Section 4: INITIALIZATION FUNCTIONS
# ============================================================================

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
# @exitcode 2 Too many apps (exceeded MAX_APPS limit)
# @stderr Error messages for invalid formats (::error:: prefix)
initialize_apps_list() {
  local -a default_apps=("$@")

  # Clear and rebuild APPS array
  APPS=()

  # Add default apps first (with validation for defense-in-depth)
  for app in "${default_apps[@]}"; do
    if ! validate_app_format "$app" >/dev/null; then
      return 1  # Fail-fast on validation error
    fi
    APPS+=("$app")
    if [ "${#APPS[@]}" -gt "$MAX_APPS" ]; then
      echo "::error::Too many apps specified (max: ${MAX_APPS})" >&2
      return 2
    fi
  done

  # Read and validate stdin apps
  if [ ! -t 0 ]; then
    local line
    while IFS= read -r line; do
      # 1. Remove inline comments (everything from # onwards)
      line="${line%%#*}"

      # 2. Strip leading/trailing whitespace
      line="${line#"${line%%[![:space:]]*}"}"  # Remove leading whitespace
      line="${line%"${line##*[![:space:]]}"}"  # Remove trailing whitespace

      # 3. Skip empty lines (after comment removal and whitespace stripping)
      if [ -n "$line" ]; then
        # Validate line (format + control characters + security)
        if ! validate_app_format "$line" >/dev/null; then
          return 1  # Fail-fast on validation error
        fi

        APPS+=("$line")
        if [ "${#APPS[@]}" -gt "$MAX_APPS" ]; then
          echo "::error::Too many apps specified (max: ${MAX_APPS})" >&2
          return 2
        fi
      fi
    done
  fi

  return 0
}

# ============================================================================
# Section 5: OUTPUT FUNCTIONS
# ============================================================================

# @description Output validation success to GITHUB_OUTPUT
# @exitcode 0 Always returns success
# @global VALIDATION_RESULTS array JSON-structured validation results
# @set GITHUB_OUTPUT Writes status=success, message, validated_apps, validated_count, failed_count=0
output_success() {
  echo "=== Application validation passed ===" >&2

  # Derive all data from VALIDATION_RESULTS
  local results_json
  results_json=$(printf '%s\n' "${VALIDATION_RESULTS[@]}" \
    | jq -s '[.[] | select(.status == "success")]')

  local all_versions validated_apps_csv validated_count
  all_versions=$(printf '%s' "$results_json" | jq -r '.[] | "  " + .app + " " + .version')
  validated_apps_csv=$(printf '%s' "$results_json" | jq -r '[.[].app] | join(",")')
  validated_count=$(printf '%s' "$results_json" | jq -r 'length')

  {
    echo "status=success"
    cat <<HEREDOC
message<<MULTILINE_EOF
Applications validated:
${all_versions}
MULTILINE_EOF
HEREDOC
    echo "validated_apps=${validated_apps_csv}"
    echo "validated_count=${validated_count}"
    echo "failed_count=0"
  } >> "$(out_status)"
}

# ============================================================================
# Section 6: MAIN ORCHESTRATOR FUNCTION
# ============================================================================

# @description Validate applications from list (main validation loop)
# @arg $@ array Application definitions (cmd|app_name|version_extractor|min_version)
# @exitcode 0 All applications validated successfully
# @exitcode 1 One or more applications failed validation (fail-fast mode)
# @set VALIDATION_RESULTS Array of JSON-structured validation results
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


    # Validate format: must be 2-field (cmd|app_name) or 4-field (cmd|app_name|extractor|version)
    local format_output format_message
    if ! format_output=$(validate_app_format "$app_def"); then
      format_message="${format_output#ERROR:}"
      handle_validation_error "$cmd" "$app_name" "" "$format_message" || return 1
    fi

    # Validate application exists (includes security check)
    local exists_output exists_message
    if ! exists_output=$(validate_app_exists "$cmd" "$app_name"); then
      exists_message="${exists_output#ERROR:}"
      handle_validation_error "$cmd" "$app_name" "" "$exists_message" || return 1
    fi

    # Get version once (used for validate_app_version and JSON entry)
    local version=""
    if command -v "$cmd" &>/dev/null; then
      version=$(get_app_version "$cmd" 2>/dev/null || true)
    fi

    # Validate application version (pass pre-fetched version to avoid second call)
    local version_output version_message
    if version_output=$(validate_app_version "$cmd" "$app_name" "$version_extractor" "$min_ver" "$version"); then
      if [[ "${version_output}" == WARNING:* ]]; then
        echo "::warning::${version_output#WARNING:}" >&2
      fi
    else
      version_message="${version_output#ERROR:}"
      handle_validation_error "$cmd" "$app_name" "$version" "$version_message" || return 1
    fi

    # Perform tool-specific validation checks (e.g., gh auth check)
    local special_output special_message
    if ! special_output=$(validate_app_special "$cmd" "$app_name"); then
      special_message="${special_output#ERROR:}"
      handle_validation_error "$cmd" "$app_name" "$version" "$special_message" || return 1
    fi

    # Append JSON success entry to structured results array
    local json_entry
    json_entry=$(jq -n \
      --arg status "success" \
      --arg app "$app_name" \
      --arg version "$version" \
      --argjson index "$VALIDATION_INDEX" \
      '{"status": $status, "app": $app, "version": $version, "index": $index}')
    VALIDATION_RESULTS+=("$json_entry")
    VALIDATION_INDEX=$(( VALIDATION_INDEX + 1 ))
  done
}

# ============================================================================
# Section 7: SCRIPT ENTRY POINT
# ============================================================================

# @description Main execution function
# @noargs
# @exitcode 0 All validations passed
# @exitcode 1 One or more validations failed
main() {
  # Require jq for JSON output
  check_jq || {
    echo "::error::jq is required but not found. Install jq before running this script." >&2
    exit 1
  }

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
  declare -a default_apps=(
    "git|Git|field:3|2.30"                   # Extract 3rd field, check min 2.30
    "curl|curl||"                            # No version check
  )

  # Build apps list from defaults + stdin (with format validation)
  # stdin is used for additional-apps input in action.yml
  # Sets global APPS array
  # Returns: 0=success, 1=format error, 2=too many apps
  local init_status=0
  initialize_apps_list "${default_apps[@]}" || init_status=$?
  if [ "$init_status" -eq 2 ]; then
    echo "::error::Too many apps specified (max: ${MAX_APPS})" >&2
    return 1
  elif [ "$init_status" -ne 0 ]; then
    echo "::error::Failed to build apps list from defaults/stdin" >&2
    return 1
  fi

  # Validate all applications (fail-fast: handle_validation_error outputs on first failure)
  validate_apps "${APPS[@]}" || return 1

  # Output success
  output_success

  return 0
}

# Only run main if script is executed directly (not sourced/included)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
  exit $?
fi
