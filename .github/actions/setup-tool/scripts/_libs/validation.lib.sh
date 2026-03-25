#!/usr/bin/env bash
# src: ./.github/actions/setup-tool/scripts/_libs/validation.lib.sh
# @(#) : Validation library for setup-tool composite action
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# shellcheck shell=bash
# DR-16: 2-layer design — backend + field-specific frontends

# Guard against double-sourcing
[[ -n "${_VALIDATION_LIB_SH:-}" ]] && return 0
readonly _VALIDATION_LIB_SH=1

# shellcheck source=logging.lib.sh
_VALIDATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_VALIDATION_LIB_DIR}/logging.lib.sh"

##
# @description Validate a trimmed value against an ERE regex pattern (internal backend)
# @arg $1 value      — raw input value (will be trimmed)
# @arg $2 field_name — name for error messages (e.g. "tool-name")
# @arg $3 pattern    — ERE regex pattern (bash [[ =~ ]])
# @stdout normalized (trimmed) value on success
# @stderr ::error:: message on failure
# @return 0 on success, 1 on failure
_validate_symbol_backend() {
  local value="$1"
  local field_name="$2"
  local pattern="$3"

  # R-000: trim leading/trailing whitespace
  value="${value#"${value%%[! $'\t']*}"}"
  value="${value%"${value##*[! $'\t']}"}"

  if [[ "$value" =~ $pattern ]]; then
    echo "$value"
    return 0
  fi

  echo "$(make_error_message "${field_name}" "invalid value '${value}'. Expected: ${pattern}")" >&2
  return 1
}

##
# @description Validate tool-name input
# @arg $1 value — raw tool-name input
# @stdout normalized tool-name on success
# @stderr ::error::tool-name: message on failure
# @return 0 on success, 1 on failure
validate_tool_name() {
  _validate_symbol_backend "$1" "tool-name" '^[a-z][a-z0-9_-]{0,63}$'
}

##
# @description Validate repo in "org/name" format (DR-17)
# @arg $1 value — raw repo input (e.g. "rhysd/actionlint")
# @stdout normalized "org/name" on success
# @stderr ::error::repo: message on failure
# @return 0 on success, 1 on failure
validate_repository() {
  local value="$1"

  # R-000: trim leading/trailing whitespace
  value="${value#"${value%%[! $'\t']*}"}"
  value="${value%"${value##*[! $'\t']}"}"

  # スラッシュが1個のみかチェック
  local slash_count="${value//[^\/]/}"
  if [[ "${#slash_count}" -ne 1 ]]; then
    echo "$(make_error_message "repo" "must be 'org/name' format (got '${value}')")" >&2
    return 1
  fi

  local org="${value%%/*}"
  local name="${value#*/}"

  # org 部の検証
  local normalized_org
  normalized_org=$(_validate_symbol_backend "$org" "repo" '^[a-z0-9][a-z0-9-]{0,38}$') || return 1

  # name 部の検証
  local normalized_name
  normalized_name=$(_validate_symbol_backend "$name" "repo" '^[A-Za-z0-9._-]{1,100}$') || return 1

  echo "${normalized_org}/${normalized_name}"
}
