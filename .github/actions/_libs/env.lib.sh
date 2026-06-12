#!/usr/bin/env bash
# src: .github/actions/_libs/env.lib.sh
# @(#) : environment variable utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

[ -n "${ENV_LIB_LOADED:-}" ] && return 0
ENV_LIB_LOADED=1

check_env_var() {
  local var_name="$1"
  local expected_value="${2:-}"
  local var_value="${!var_name:-}"

  [ -n "$var_value" ] || return 1
  [ -z "$expected_value" ] || [ "$var_value" = "$expected_value" ] || return 1

  return 0
}
