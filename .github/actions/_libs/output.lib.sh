#!/usr/bin/env bash
# src: .github/actions/_libs/output.lib.sh
# @(#) : output utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

[ -n "${OUTPUT_LIB_LOADED:-}" ] && return 0
OUTPUT_LIB_LOADED=1

out_status() {
  echo "${GITHUB_OUTPUT:-/dev/null}"
}

write_status() {
  echo "status=$1" >>"${GITHUB_OUTPUT:-/dev/null}"
  echo "message=$2" >>"${GITHUB_OUTPUT:-/dev/null}"
}

##
# @description Append one "<key>=<value>" line to an output file.
#              Existing content is kept; the line is appended with >>.
#              Unlike write_status, an empty <file> is rejected; it never falls back to /dev/null.
# @arg $1 file  — output file path to append to (required)
# @arg $2 key   — output key (not validated here; the caller guarantees it)
# @arg $3 value — output value (may be empty; must not contain CR or LF)
# @stdout (none)
# @stderr (none) on every path, including write failures
# @return 0 on success
# @return 1 on invalid args (empty <file>, <value> containing CR or LF); nothing is written
# @return 2 on write failure (<file> is a directory, its parent directory is missing, etc.)
write_output() {
  local file="$1"
  local key="$2"
  local value="$3"

  [[ -n "$file" ]] || return 1
  [[ "$value" != *[$'\r\n']* ]] || return 1

  # the group redirect also silences the error raised by the >> redirection itself
  { printf '%s=%s\n' "$key" "$value" >>"$file"; } 2>/dev/null || return 2
}
