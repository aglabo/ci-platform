#!/usr/bin/env bash
# src: .github/actions/_libs/validation.lib.sh
# @(#) : validation utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

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
