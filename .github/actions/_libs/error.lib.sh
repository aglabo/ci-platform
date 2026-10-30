#!/usr/bin/env bash
# src: .github/actions/_libs/error.lib.sh
# @(#) : error reporting utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Load guard: return early when this library has already been loaded. An empty
# ERROR_LIB_LOADED counts as "not loaded". The readonly constants below must
# stay after the guard: re-sourcing would otherwise fail on redefining them.
[ -n "${ERROR_LIB_LOADED:-}" ] && return 0
ERROR_LIB_LOADED=1

# gha_error <target> for errors about the step output file ($GITHUB_OUTPUT)
readonly GHA_TARGET_GITHUB_OUTPUT=GITHUB_OUTPUT
# gha_error <problem>: the output file path is not a writable regular file
readonly GHA_MSG_NOT_WRITABLE="is not a writable file"
# gha_error <problem>: writing to the output file failed
readonly GHA_MSG_WRITE_FAILED="failed to write"

##
# @description Emit a GitHub Actions error annotation. The form is chosen by
#              argument count, not by whether the value is empty:
#              - 3 arguments (normal form):
#                "::error::<target>: <problem> (got: '<value>')"
#                (an explicitly passed "" still uses this form)
#              - fewer than 3 arguments (empty form; callers pass <target> only):
#                "::error::<target>: value must not be empty"
#              <value> is encoded so that it cannot break the line or inject a
#              workflow command: "%" -> "%25" first, then CR -> "%0D" and
#              LF -> "%0A". <target> and <problem> are printed as is.
# @arg $1 target  — name of the offending input or variable (e.g. "commit-count")
# @arg $2 problem — short description of what is wrong (e.g. "invalid")
# @arg $3 value   — optional; when omitted, the empty form is used
# @stdout (none)
# @stderr one ::error:: line
# @return 0 always (exiting non-zero is the caller's responsibility)
gha_error() {
  if [ "$#" -lt 3 ]; then
    printf "::error::%s: value must not be empty\n" "$1" >&2
    return 0
  fi
  local _value="$3"
  _value="${_value//%/%25}"
  _value="${_value//$'\r'/%0D}"
  _value="${_value//$'\n'/%0A}"
  printf "::error::%s: %s (got: '%s')\n" "$1" "$2" "$_value" >&2
}
