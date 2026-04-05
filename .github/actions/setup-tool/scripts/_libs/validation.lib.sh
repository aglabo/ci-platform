#!/bin/bash
# shellcheck shell=bash
# @description Validation library for setup-tool composite action
# Module: composite-action/setup-tool

# Guard against double-sourcing
[[ -n "${_VALIDATION_LIB_SH:-}" ]] && return 0
readonly _VALIDATION_LIB_SH=1

##
# @description Validate a value against a whitelist ERE regex pattern
# @arg $1 value      — the value to validate
# @arg $2 field_name — name for error messages (e.g. "tool-name")
# @arg $3 pattern    — ERE regex pattern (bash [[ =~ ]])
# @stdout (none)
# @stderr ::error::<field_name>: invalid value '<value>'. Expected: <pattern>  (on failure only)
# @return 0 on match, 1 on mismatch
validate_symbol() {
  local value="$1"
  local field_name="$2"
  local pattern="$3"

  if [[ "$value" =~ $pattern ]]; then
    return 0
  fi

  echo "::error::${field_name}: invalid value '${value}'. Expected: ${pattern}" >&2
  return 1
}
