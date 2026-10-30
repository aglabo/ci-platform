#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh
# @(#) : helper functions for the ca-get-changed-files composite action
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# ============================================================================
# Load Guard / Dependencies
# ============================================================================

# Load guard: return early when this library has already been loaded. The
# guard is set first; a failed load of output.lib.sh / validation.lib.sh below
# returns 1, which makes the action fail, so the library is never sourced
# again afterwards.
[ -n "${GET_CHANGED_FILES_LIB_LOADED:-}" ] && return 0
GET_CHANGED_FILES_LIB_LOADED=1

# Directory of the shared libraries (.github/actions/_libs)
_GCF_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/_libs"
# shellcheck source=.github/actions/_libs/output.lib.sh
# shellcheck disable=SC1091
. "${_GCF_COMMON_LIB_DIR}/output.lib.sh" || return 1
# shellcheck source=.github/actions/_libs/validation.lib.sh
# shellcheck disable=SC1091
. "${_GCF_COMMON_LIB_DIR}/validation.lib.sh" || return 1

# ============================================================================
# Constants
# ============================================================================

# Byte limit of the changed-file list (DR-13; R-DIF-003), measured on the
# list joined by LF with no trailing LF; a list of exactly the limit is accepted.
# Public, like FF_MAX_FILES_BYTES of _ca-filter-files, which it must match
# (R-DIF-033). Defined after the load guard is set, so a second source
# returns at the guard and never re-runs readonly (which would fail).
readonly GCF_MAX_FILES_BYTES=120000

# ============================================================================
# Constants: Error Wording (specifications-diff.md "エラーの文言")
# ============================================================================

# The wording shared with the other actions (the GITHUB_OUTPUT target, "is
# not a writable file", "failed to write") is GHA_TARGET_* / GHA_MSG_* of
# _libs/error.lib.sh; only the wording of this action is defined here.

# Target of the errors about the changed-file list
readonly _GCF_TARGET_FILES=files
# R-DIF-010: target of the error about an empty BEFORE_SHA (empty form)
readonly _GCF_TARGET_BEFORE_SHA=BEFORE_SHA
# R-DIF-011: target of the error about an empty AFTER_SHA (empty form)
readonly _GCF_TARGET_AFTER_SHA=AFTER_SHA
# R-DIF-002: git diff failed; the value is "<before>..<after>"
readonly _GCF_MSG_LIST_FAILED="failed to list changed files"

# ============================================================================
# Public API: Changed Files
# ============================================================================

##
# @description Print the files added, copied, modified or renamed between
#              <before> and <after>, as listed by
#              "git -c core.quotePath=false diff --name-only --diff-filter=ACMR
#              --end-of-options <before> <after>" run in the current directory,
#              with no pathspec (R-DIF-001). --end-of-options makes git read
#              both as revisions, so a value starting with "-" is never taken
#              as an option (DD-DIF-01).
#              The list is printed as is, in git's order (R-DIF-004), with
#              printf '%s'. The command substitution drops the trailing LF,
#              so the list is joined by LF with no trailing LF; an empty
#              list prints nothing and succeeds.
#              When git diff fails, git's stderr is passed through as is and
#              one error line follows it (R-DIF-002, DR-14); nothing is
#              printed on stdout.
#              When the list is longer than GCF_MAX_FILES_BYTES bytes, one
#              error line whose value is the length in bytes is printed
#              instead of the list (R-DIF-003, DR-13); a list of exactly the
#              limit is accepted. The limit is checked with check_byte_limit
#              (_libs/validation.lib.sh), which counts bytes under its own
#              local LC_ALL=C.
# @arg $1 before — commit-ish of the base side
# @arg $2 after  — commit-ish of the head side
# @stdout the changed files separated by LF, with no trailing LF;
#         nothing when the list is empty or on failure
# @stderr (none) on success; on failure, git's output followed by
#         "::error::files: failed to list changed files (got: '<before>..<after>')",
#         the value encoded by gha_error; when the list is too large,
#         "::error::files: exceeds the limit of <GCF_MAX_FILES_BYTES> bytes
#         (got: '<bytes>')" on one line
# @return 0 on success, 1 when git diff fails or the list is too large
list_changed_files() {
  local _files

  _files="$(git -c core.quotePath=false diff --name-only --diff-filter=ACMR --end-of-options "$1" "$2")" || {
    gha_error "$_GCF_TARGET_FILES" "$_GCF_MSG_LIST_FAILED" "$1..$2"
    return 1
  }
  check_byte_limit "$_GCF_TARGET_FILES" "$_files" "$GCF_MAX_FILES_BYTES" || return 1
  printf '%s' "$_files"
}
