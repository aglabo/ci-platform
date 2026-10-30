#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/get-changed-files.sh
# @(#) : list the files changed between BEFORE_SHA and AFTER_SHA and write them to GITHUB_OUTPUT
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

# Directory of this script, resolved to an absolute path. dirname (not
# ${BASH_SOURCE[0]%/*}) yields "." for a path without a slash, so running
# `bash get-changed-files.sh` from this directory still finds _libs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_libs/get-changed-files.lib.sh"

##
# @description Script-private helper of main (no test ID of its own; verified
#              through the main tests). Check the inputs before anything is
#              listed, in this order and stopping at the first failure, so
#              nothing is written on failure: an empty BEFORE_SHA (R-DIF-010),
#              AFTER_SHA (R-DIF-011) or GITHUB_OUTPUT (R-DIF-012), reported in
#              the empty form; then a GITHUB_OUTPUT that is not a writable
#              file, a directory say (R-DIF-013), checked with
#              validate_output_file. Unset variables are treated as empty.
# @env BEFORE_SHA — commit-ish of the base side
# @env AFTER_SHA — commit-ish of the head side
# @env GITHUB_OUTPUT — step output file
# @stdout (none)
# @stderr one ::error:: line when a check fails
# @return 0 when every check passes, 1 at the first failure
_main_check_inputs() {
  local _target

  # Each target constant is the name of the variable it reports (the shared
  # GHA_TARGET_GITHUB_OUTPUT too: GITHUB_OUTPUT), so the value is read through
  # it by indirection.
  for _target in "$_GCF_TARGET_BEFORE_SHA" "$_GCF_TARGET_AFTER_SHA" "$GHA_TARGET_GITHUB_OUTPUT"; do
    [ -n "${!_target:-}" ] || {
      gha_error "$_target"
      return 1
    }
  done
  # R-DIF-013: validate_output_file returns 1 only for an empty path, which
  # the loop above has already reported (R-DIF-012), so any failure here means
  # GITHUB_OUTPUT is not a writable file.
  validate_output_file "$GITHUB_OUTPUT" || {
    gha_error "$GHA_TARGET_GITHUB_OUTPUT" "$GHA_MSG_NOT_WRITABLE" "$GITHUB_OUTPUT"
    return 1
  }
}

##
# @description Entry point of the ca-get-changed-files composite action.
#              Together with _main_check_inputs, the only place that reads
#              the environment; unset variables are treated as empty. Calls, in this fixed order and stopping at
#              the first failure: _main_check_inputs (R-DIF-010 -> R-DIF-011
#              -> R-DIF-012 -> R-DIF-013; nothing is written on failure) ->
#              list_changed_files, run in the current directory (R-DIF-002 /
#              R-DIF-003; nothing is written on failure) ->
#              write_multiline_output, which writes the list, one per line in
#              git's order, as the multiline files output (R-DIF-015). When
#              that write fails, the error is reported here (R-DIF-016);
#              output already written may remain.
#              Error lines on stderr are emitted with gha_error; main writes
#              no wording itself and uses the _GCF_TARGET_* / _GCF_MSG_*
#              constants of this action and the shared GHA_TARGET_* /
#              GHA_MSG_* constants (_libs/error.lib.sh).
# @env BEFORE_SHA — commit-ish of the base side
# @env AFTER_SHA — commit-ish of the head side
# @env GITHUB_OUTPUT — step output file (files)
# @stdout (none)
# @stderr (none) on success; one ::error:: line on error, preceded by git's
#         own output when git diff fails (R-DIF-002)
# @return 0 on success, 1 when any step fails
main() {
  local _list
  local -a _lines=()

  _main_check_inputs || return 1
  # Assigned apart from "local", so a failure is not masked by its status
  _list="$(list_changed_files "${BEFORE_SHA:-}" "${AFTER_SHA:-}")" || return 1
  # A here-string of an empty list reads as one empty line, so an empty list
  # passes no line arguments (R-DIF-015)
  [ -z "$_list" ] || mapfile -t _lines <<<"$_list"
  # R-DIF-016: write_multiline_output reports nothing itself, so main reports
  # the failure (any non-zero status)
  write_multiline_output "$GITHUB_OUTPUT" files "${_lines[@]}" || {
    gha_error "$_GCF_TARGET_FILES" "$GHA_MSG_WRITE_FAILED" "$GITHUB_OUTPUT"
    return 1
  }
}

# Run main only when executed, not when sourced. `return` succeeds only while
# a file is being sourced (or inside a function), so the subshell fails when
# the script is executed. Unlike comparing ${BASH_SOURCE[0]} with $0, this does
# not depend on how the path is spelled.
if ! (return 0 2>/dev/null); then
  main "$@"
  exit $?
fi
