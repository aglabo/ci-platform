#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-config/scripts/_libs/resolve-config.lib.sh
# @(#) : helper functions for the _ca-resolve-config composite action
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# Load guard: return early when this library has already been loaded.
[ -n "${RESOLVE_CONFIG_LIB_LOADED:-}" ] && return 0
RESOLVE_CONFIG_LIB_LOADED=1

# Directory of the shared libraries (.github/actions/_libs)
_RC_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/_libs"
# shellcheck source=.github/actions/_libs/error.lib.sh
# shellcheck disable=SC1091
. "${_RC_COMMON_LIB_DIR}/error.lib.sh" || return 1
# shellcheck source=.github/actions/_libs/path.lib.sh
# shellcheck disable=SC1091
. "${_RC_COMMON_LIB_DIR}/path.lib.sh" || return 1

##
# @description Make <value> an absolute path under GITHUB_WORKSPACE and confirm
#              it is acceptable; the checks are done by validate_path.
# @arg $1 target — input name used in the error message
# @arg $2 value  — config path (non-empty)
# @stdout the absolute path; nothing on error
# @stderr one ::error:: line on error
# @return 0 on success, 1 when the path is rejected
_rc_resolve() {
  validate_path "$1" "$2" "$GITHUB_WORKSPACE"
}

##
# @description Check one candidate: an empty <value> is skipped; otherwise the
#              path is validated by _rc_resolve and, when it names a regular
#              file, reported as "<path> <source>". The value is never
#              evaluated.
# @arg $1 target — input name used in the error message
# @arg $2 value  — candidate path (may be empty)
# @arg $3 source — source label (input | local | global)
# @stdout "<path> <source>" as one line when the candidate is a regular file
# @stderr one ::error:: line when the path is rejected
# @return 0 when the candidate is used, 1 when the path is rejected,
#         2 when the candidate is empty or not a regular file
_rc_try() {
  local _target="$1" _value="$2" _source="$3" _path
  [[ -n $_value   ]] || return 2
  _path="$(_rc_resolve "$_target" "$_value")" || return 1
  [[ -f $_path   ]] || return 2
  printf '%s %s\n' "$_path" "$_source"
}

##
# @description Resolve the configuration file to use, relative paths being
#              taken from GITHUB_WORKSPACE. A non-empty <config> is the only
#              candidate: when it is not a regular file it is an error and
#              there is no fallback. Otherwise <local_config> and then
#              <global_config> are tried. Any path with a ".." segment,
#              whitespace, or outside GITHUB_WORKSPACE is rejected.
# @arg $1 config        — config input
# @arg $2 local_config  — local config path
# @arg $3 global_config — global config path
# @stdout "<path> <source>" as one line on success (source = input | local |
#         global); nothing on error
# @stderr one ::error:: line on error
# @return 0 on success, 1 on error
resolve_config() {
  local _config="$1" _local="$2" _global="$3" _status
  if [[ -z ${GITHUB_WORKSPACE:-}   ]]; then
    gha_error GITHUB_WORKSPACE
    return 1
  fi
  if [[ -n $_config   ]]; then
    _rc_try config "$_config" input
    _status=$?
    if ((_status == 2)); then
      gha_error config "file not found" "$_config"
      return 1
    fi
    return "$_status"
  fi
  _rc_try local_config "$_local" local
  _status=$?
  ((_status == 2)) || return "$_status"
  _rc_try global_config "$_global" global
  _status=$?
  ((_status == 2)) || return "$_status"
  gha_error config "no configuration file found" "${_local:-$_global}"
  return 1
}
