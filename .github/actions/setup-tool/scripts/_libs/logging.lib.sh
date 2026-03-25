#!/usr/bin/env bash
# src: ./.github/actions/setup-tool/scripts/_libs/logging.lib.sh
# @(#) : Message generation library for setup-tool composite action
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# shellcheck shell=bash
# DR-15: Message generation only — output is caller's responsibility

# Guard against double-sourcing
[[ -n "${_LOGGING_LIB_SH:-}" ]] && return 0
readonly _LOGGING_LIB_SH=1

##
# @description Generate a GitHub Actions error annotation message
# @arg $1 field_name — field identifier (e.g. "tool-name")
# @arg $2 message    — error description
# @stdout ::error::<field_name>: <message>
# @return 0
make_error_message() {
  local field_name="$1"
  local message="$2"
  echo "::error::${field_name}: ${message}"
}

##
# @description Generate a GitHub Actions warning annotation message
# @arg $1 field_name — field identifier
# @arg $2 message    — warning description
# @stdout ::warning::<field_name>: <message>
# @return 0
make_warning_message() {
  local field_name="$1"
  local message="$2"
  echo "::warning::${field_name}: ${message}"
}

##
# @description Generate a GitHub Actions notice annotation message
# @arg $1 message — notice description
# @stdout ::notice::<message>
# @return 0
make_notice_message() {
  local message="$1"
  echo "::notice::${message}"
}
