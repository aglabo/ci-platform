#!/usr/bin/env bash
# src: .github/actions/_libs/validation.lib.sh
# @(#) : validation utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Load guard: return early when this library has already been loaded. The
# guard is set first; a failed load of error.lib.sh below returns 1, which
# makes the action fail, so the library is never sourced again afterwards.
[ -n "${VALIDATION_LIB_LOADED:-}" ] && return 0
VALIDATION_LIB_LOADED=1

# error.lib.sh (gha_error) is loaded from this library's own directory. The
# private _VALIDATION_LIB_DIR is unset after a successful load so that no name
# leaks into the caller (callers such as validate-inputs.lib.sh rely on their
# SCRIPT_DIR); a failed load fails the action, so it is left as is.
_VALIDATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_libs/error.lib.sh
# shellcheck disable=SC1091
. "${_VALIDATION_LIB_DIR}/error.lib.sh" || return 1
unset _VALIDATION_LIB_DIR

##
# @description Validate a value against a whitelist ERE regex pattern.
#              The pattern is automatically anchored (^ / $) if not already present.
# @arg $1 value      — the value to validate
# @arg $2 field_name — name for error messages (e.g. "tool-name")
# @arg $3 pattern    — ERE regex pattern (bash [[ =~ ]]); ^ and $ auto-added if absent
# @arg $4 max_length — maximum allowed length; 0 = no limit (default: 63)
# @stdout (none)
# @stderr ::error:: message on failure only
# @return 0 on success, 1 on failure
validate_symbol() {
  local value="$1"
  local field_name="$2"
  local pattern="$3"
  local max_length="${4:-63}"

  # normalize pattern: add ^ at start and $ at end if not present
  [[ "$pattern" != ^* ]] && pattern="^${pattern}"
  [[ "$pattern" != *$ ]] && pattern="${pattern}$"

  if [[ ${#value} -eq 0 ]]; then
    echo "::error::${field_name}: value must not be empty" >&2
    return 1
  fi

  if [[ "$max_length" -gt 0 && ${#value} -gt "$max_length" ]]; then
    echo "::error::${field_name}: value too long (${#value} > ${max_length})" >&2
    return 1
  fi

  if [[ ! "$value" =~ $pattern ]]; then
    echo "::error::${field_name}: invalid value '${value}'. Expected: ${pattern}" >&2
    return 1
  fi
}

##
# @description Validate a GitHub repository identifier (owner/repo format).
#              Delegates to validate_symbol with a combined ERE pattern.
# @arg $1 repo_id    — "owner/repo" string to validate
# @arg $2 field_name — name for error messages (default: "repo")
# @stdout (none)
# @stderr ::error:: message on failure only
# @return 0 on success, 1 on failure
validate_repo() {
  local repo_id="$1"
  local field_name="${2:-repo}"

  validate_symbol "$repo_id" "$field_name" \
    '^[a-zA-Z][a-zA-Z0-9-]{0,38}/[a-zA-Z0-9_.-]{1,100}$' 140
}

##
# @description Validate a version string (X.Y.Z or X.Y format, optional v/V prefix).
#              Delegates to validate_symbol with a combined ERE pattern.
# @arg $1 version    — version string to validate (e.g. "1.2.3", "v1.2", "V2.0.0")
# @arg $2 field_name — name for error messages (default: "version")
# @stdout (none)
# @stderr ::error:: message on failure only
# @return 0 on success, 1 on failure
validate_version() {
  local version="$1"
  local field_name="${2:-version}"

  validate_symbol "$version" "$field_name" \
    '^[vV]?[0-9]+\.[0-9]+(\.[0-9]+)?$' 0
}

##
# @description Validate that a value is a positive integer not greater than max.
#              Checks run in order: format, digit count, numeric comparison.
#              The digit-count check rejects values longer than max before the
#              arithmetic comparison, so 64-bit overflow cannot wrap them into range.
#              Reports the result by exit status only; error messages are the caller's job.
#              Format matching uses the C locale, so non-ASCII digits are rejected.
# @arg $1 value — the value to validate
# @arg $2 max   — upper bound (trusted internal argument; not validated)
# @stdout (none)
# @stderr (none)
# @return 0 if valid, non-zero otherwise
validate_positive_int() {
  local value="$1"
  local max="$2"
  local LC_ALL=C

  [[ "$max" =~ ^[1-9][0-9]{0,17}$ ]] || return 2
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || return 1
  ((${#value} <= ${#max})) || return 1
  ((value <= max))
}

##
# @description Check that a value is within a byte limit. A value of exactly
#              the limit is accepted; only a value longer than <max> bytes
#              (> max) is reported via gha_error as
#              "<target>: exceeds the limit of <max> bytes (got: '<bytes>')".
#              The length is counted under a function-local LC_ALL=C, so it
#              is a byte count whatever the caller's locale is.
#              LC_ALL=C must be set in its own local statement: in a single
#              "local LC_ALL=C _bytes=${#2}" the ${#2} is expanded before
#              LC_ALL=C takes effect and counts characters.
# @arg $1 target — name of the checked value, used in the error message
# @arg $2 text   — the value to check
# @arg $3 max    — byte limit (trusted internal argument; not validated)
# @stdout (none)
# @stderr (none) when the value is within the limit; one ::error::<target>:
#         line when it exceeds the limit
# @return 0 when the value is within the limit, 1 when it exceeds the limit
check_byte_limit() {
  local LC_ALL=C
  local _bytes=${#2}

  if ((_bytes > $3)); then
    gha_error "$1" "exceeds the limit of $3 bytes" "$_bytes"
    return 1
  fi
  return 0
}
