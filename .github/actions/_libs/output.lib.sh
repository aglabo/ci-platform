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

##
# @description Print the first of EOF, EOF_1, EOF_2, ... that equals none of the <line> arguments.
#              Only a whole-argument match collides; "xEOF" or "EOF " does not.
# @arg $@ line  — lines to be written inside the multi-line block (may be none)
# @stdout the chosen delimiter (without a trailing LF)
# @stderr (none)
# @return 0 always
_multiline_delimiter() {
  local delimiter="EOF"
  local n=0

  while _has_line "$delimiter" "$@"; do
    n=$((n + 1))
    delimiter="EOF_${n}"
  done
  printf '%s' "$delimiter"
}

##
# @description Test whether any <line> argument equals <target> exactly.
# @arg $1 target — string to look for
# @arg $2 line   — lines to search, one per argument (from $2 onward; may be none)
# @stdout (none)
# @stderr (none)
# @return 0 if a <line> equals <target>
# @return 1 otherwise
_has_line() {
  local target="$1"
  local line

  shift
  for line in "$@"; do
    [[ "$line" != "$target" ]] || return 0
  done
  return 1
}

##
# @description Append a multi-line "<key><<<delimiter>" ... "<delimiter>" block to an output file.
#              Existing content is kept; the block is appended with >>.
#              Each <line> argument is written as-is as one line between the header and delimiter lines;
#              with no <line> arguments, only the header and delimiter lines are written.
#              The delimiter is chosen by _multiline_delimiter.
#              Unlike write_status, an empty <file> is rejected; it never falls back to /dev/null.
# @arg $1 file  — output file path to append to (required)
# @arg $2 key   — output key (must match ^[A-Za-z_][A-Za-z0-9_-]*$)
# @arg $3 line  — lines to write, one per argument (from $3 onward; may be none; must not contain CR or LF)
# @stdout (none)
# @stderr (none) on every path, including write failures
# @return 0 on success
# @return 1 on invalid args (empty <file>, malformed <key>, any <line> containing CR or LF); nothing is written
# @return 2 on write failure (<file> is a directory, its parent directory is missing, etc.)
write_multiline_output() {
  local file="$1"
  local key="$2"
  local line
  local delimiter

  [[ -n "$file" ]] || return 1
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || return 1
  shift 2
  for line in "$@"; do
    [[ "$line" != *[$'\r\n']* ]] || return 1
  done
  delimiter=$(_multiline_delimiter "$@")

  # the group redirect also silences the error raised by the >> redirection itself
  { printf '%s\n' "${key}<<${delimiter}" "$@" "$delimiter" >>"$file"; } 2>/dev/null || return 2
}
