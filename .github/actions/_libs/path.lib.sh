#!/usr/bin/env bash
# src: .github/actions/_libs/path.lib.sh
# @(#) : path validation helper for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# Load guard: return early when this library has already been loaded.
[ -n "${PATH_LIB_LOADED:-}" ] && return 0
PATH_LIB_LOADED=1

_PATH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_libs/error.lib.sh
# shellcheck disable=SC1091
. "${_PATH_LIB_DIR}/error.lib.sh" || return 1

##
# @description Make <value> an absolute path under <root> and confirm it is
#              acceptable. Rejected: an empty value, a value with whitespace
#              or a ".." segment, a path not strictly inside <root> (the root
#              itself is rejected), and a path whose symlink-resolved location
#              is outside the resolved <root>. A path that cannot be resolved
#              (missing, dangling) is accepted; existence is the caller's
#              concern. Whitespace in <root> is allowed. The printed path is
#              the unresolved one.
# @arg $1 target — input name used in the error message
# @arg $2 value  — path, absolute or relative to <root>
# @arg $3 root   — base directory
# @stdout the absolute path; nothing on error
# @stderr one ::error:: line on error
# @return 0 on success, 1 when the path is rejected
validate_path() {
  local _target="$1" _value="$2" _root="$3"
  if [[ -z $_value ]]; then
    gha_error "$_target"
    return 1
  fi
  if [[ "/${_value}/" == */../* ]]; then
    gha_error "$_target" "must not contain '..'" "$_value"
    return 1
  fi
  if [[ $_value =~ [[:space:]] ]]; then
    gha_error "$_target" "must not contain whitespace" "$_value"
    return 1
  fi
  local _abs
  case "$_value" in
    /*) _abs="$_value" ;;
    *) _abs="${_root%/}/${_value}" ;;
  esac
  if [[ $_abs != "${_root%/}"/* ]]; then
    gha_error "$_target" "must be inside the root" "$_value"
    return 1
  fi
  # Resolve symlinks (both sides) and require the real path to stay inside the
  # real root. A path that cannot be resolved is left to the caller. The
  # resolution sits in an "if" condition so a failure never aborts under set -e.
  local _real _real_root
  if _real="$(realpath -- "$_abs" 2> /dev/null)" && _real_root="$(realpath -- "$_root" 2> /dev/null)"; then
    if [[ $_real != "${_real_root%/}"/* ]]; then
      gha_error "$_target" "must not resolve outside the root" "$_value"
      return 1
    fi
  fi
  printf '%s\n' "$_abs"
}
