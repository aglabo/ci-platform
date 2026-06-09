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
