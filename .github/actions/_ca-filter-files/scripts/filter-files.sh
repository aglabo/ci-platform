#!/usr/bin/env bash
# src: .github/actions/_ca-filter-files/scripts/filter-files.sh
# @(#) : filter the files input by the patterns input and write the kept files to GITHUB_OUTPUT
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

# Directory of this script, resolved to an absolute path. dirname (not
# ${BASH_SOURCE[0]%/*}) yields "." for a path without a slash, so running
# `bash filter-files.sh` from this directory still finds _libs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_ca-filter-files/scripts/_libs/filter-files.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_libs/filter-files.lib.sh"

##
# @description Script-private helper of main (no test ID of its own; verified
#              through the main tests). Run the checks on the raw input
#              values, before any conversion or splitting, in the DR-14
#              order and stopping at the first failure: check_byte_limit
#              (files -> patterns), then check_line_endings (files ->
#              patterns).
# @arg $1 files    — raw value of the files input
# @arg $2 patterns — raw value of the patterns input
# @stdout (none)
# @stderr one ::error:: line when a check fails
# @return 0 when every check passes, 1 at the first failure
_main_check_raw_inputs() {
  check_byte_limit files "$1" "$FF_MAX_FILES_BYTES" || return 1
  check_byte_limit patterns "$2" "$FF_MAX_PATTERNS_BYTES" || return 1
  check_line_endings files "$1" || return 1
  check_line_endings patterns "$2" || return 1
}

##
# @description Entry point of the _ca-filter-files composite action. The only
#              place that reads the environment; unset variables are treated
#              as empty. Calls, in this fixed order and stopping at the first
#              failure (DR-14), files before patterns at each stage:
#              check_byte_limit -> check_line_endings -> parse_filelist /
#              parse_patterns -> check_line_limit -> check_patterns ->
#              filter_files -> emit_outputs.
#              The first two stages run in _main_check_raw_inputs.
#              check_patterns only validates; the parse_patterns result
#              (the pattern lines) is passed to filter_files as is (DR-19).
#              Error lines on stderr come from the library; main prints
#              nothing itself.
# @env INPUT_FILES — files input (newline separated file paths)
# @env INPUT_PATTERNS — patterns input (newline separated globs, "!" excludes)
# @env GITHUB_OUTPUT — step output file (files / count)
# @stderr one ::error:: line on error
# @return 0 on success, 1 when any stage fails
main() {
  local _files _patterns _kept

  _main_check_raw_inputs "${INPUT_FILES:-}" "${INPUT_PATTERNS:-}" || return 1
  _files=$(parse_filelist "${INPUT_FILES:-}") || return 1
  _patterns=$(parse_patterns "${INPUT_PATTERNS:-}") || return 1
  check_line_limit files "$_files" "$FF_MAX_FILES" || return 1
  check_line_limit patterns "$_patterns" "$FF_MAX_PATTERNS" || return 1
  check_patterns "$_patterns" || return 1

  # Command substitution drops the trailing LF of the last kept line
  _kept=$(filter_files "$_files" "$_patterns") || return 1
  emit_outputs "${GITHUB_OUTPUT:-}" "$_kept" || return 1
}

# Run main only when executed, not when sourced. `return` succeeds only while
# a file is being sourced (or inside a function), so the subshell fails when
# the script is executed. Unlike comparing ${BASH_SOURCE[0]} with $0, this does
# not depend on how the path is spelled: when bash finds the script through
# PATH, BASH_SOURCE[0] is the full path while $0 is the bare name.
if ! (return 0 2>/dev/null); then
  main "$@"
  exit $?
fi
