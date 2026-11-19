#!/usr/bin/env bash
# src: .github/actions/ca-run-secretlint/scripts/_libs/inputs.lib.sh
# @(#) : input validation functions for ca-run-secretlint
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

[ -n "${RSL_INPUTS_LIB_LOADED:-}" ] && return 0
RSL_INPUTS_LIB_LOADED=1

##
# @description Validate the secretlint-version input: strictly X.Y.Z digits with major >= 14
#              (no v prefix, no suffix, no dist-tag, not empty; the major has no leading zeros).
# @arg $1 string version
# @stderr ::error:: annotation on failure
# @return 0 when valid, 1 otherwise
validate_secretlint_version() {
  local _version="${1:-}"
  if [[ ! $_version =~ ^(1[4-9]|[2-9][0-9]|[1-9][0-9]{2,})\.[0-9]+\.[0-9]+$ ]]; then
    gha_error "secretlint-version" "must be in X.Y.Z format with major version 14 or later" "$_version"
    return 1
  fi
  return 0
}
