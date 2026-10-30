#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/__tests__/functional/get-changed-files.functional.spec.sh
# @(#) : functional tests for get-changed-files.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Functional test suite for get-changed-files.sh
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: ca-get-changed-files/scripts/get-changed-files.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# Script under test; executed with bash (not Included) by _mainf_run
_MAINF_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/get-changed-files.sh"

# --- ヘルパー ---
# Real git repository fixtures (gf_setup / gf_cleanup / gf_init_repo / gf_git / gf_run_in)
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"

# --- 内部ヘルパー ---
# 定数
# Exit code of the fixture runners (_mainf_run_*) when the fixture setup fails
# (returned by _setup_failed); no T-GCF-MAINF case expects it
_SETUP_FAILED=98
# Line written to the output file before the script runs
# (_mainf_write_existing_line): kept with the files output appended after it
# on success (T-GCF-MAINF-04), left as the only content on a check failure
# (T-GCF-MAINF-22)
_MAINF_EXISTING_LINE='prev=1'
# 40-hex SHA that no fixture repository contains; used by T-GCF-MAINF-11 / 16
_MISSING_SHA=1111111111111111111111111111111111111111
# files output of the _mainf_run_modify_add diff; used by T-GCF-MAINF-01 / 18
_MAINF_MODIFY_ADD_FILES=$'a.sh\nb.md'
# Output block the script writes for that diff; used by T-GCF-MAINF-01 / 04 / 18
_MAINF_MODIFY_ADD_BLOCK="files<<EOF"$'\n'"${_MAINF_MODIFY_ADD_FILES}"$'\n'"EOF"
# Output block the script writes for an empty list (no lines between the
# delimiters); used by T-GCF-MAINF-05 / 06
_MAINF_EMPTY_BLOCK=$'files<<EOF\nEOF'
# Output block the script writes for a file named EOF (delimiter EOF_1);
# used by T-GCF-MAINF-19
_MAINF_EOF_BLOCK=$'files<<EOF_1\nEOF\nEOF_1'
# stderr line for an empty BEFORE_SHA (R-DIF-010); used by
# T-GCF-MAINF-07 / 15 / 22
_MAINF_ERR_BEFORE_EMPTY='::error::BEFORE_SHA: value must not be empty'
# stderr line for an empty or unset GITHUB_OUTPUT (R-DIF-012); used by
# T-GCF-MAINF-09 / 17
_MAINF_ERR_OUTPUT_EMPTY='::error::GITHUB_OUTPUT: value must not be empty'

# 関数

##
# Report a fixture setup failure on stderr and return _SETUP_FAILED, so the
# failure is detected inside the It that builds the fixture.
# @arg $1 name — name of the failed fixture (for the message)
# @stderr "<name> fixture setup failed"
# @return _SETUP_FAILED (98)
_setup_failed() {
  echo "$1 fixture setup failed" >&2
  return "$_SETUP_FAILED"
}

##
# Prepare the per-example environment: the fixture root (gf_setup), an empty
# step output file in it, and an environment isolated from the host. Unsets
# every variable the script or its libraries read, except GITHUB_OUTPUT:
# BEFORE_SHA / AFTER_SHA (each case exports them again), the GITHUB_* event
# variables, every INPUT_*, the old PATTERN, and every *_LIB_LOADED load
# guard (so an inherited guard never makes a library source a no-op).
# Used by every case (BeforeEach).
# Sets: _MAINF_OUTPUT — the output file path (empty).
# Exports: GITHUB_OUTPUT="$_MAINF_OUTPUT".
# ShellSpec skips every AfterEach when a BeforeEach fails, so a step that fails
# after gf_setup removes the fixture root here.
# @return 0 on success, 1 when any step fails
_mainf_setup() {
  local _mainf_var

  gf_setup || return 1
  _MAINF_OUTPUT="${GF_TMP_ROOT}/github_output"
  : >"$_MAINF_OUTPUT" || {
    gf_cleanup
    return 1
  }
  export GITHUB_OUTPUT="$_MAINF_OUTPUT"
  unset BEFORE_SHA AFTER_SHA PATTERN \
    GITHUB_EVENT_NAME GITHUB_REF GITHUB_EVENT_DELETED \
    GITHUB_BEFORE_SHA GITHUB_AFTER_SHA GITHUB_BASE_SHA GITHUB_HEAD_SHA
  for _mainf_var in $(compgen -e INPUT_) $(compgen -v | grep '_LIB_LOADED$'); do
    unset "$_mainf_var"
  done
  return 0
}

##
# Commit what is staged in the index of <repo> and print the new commit OID.
# The single place where the fixtures create a commit.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_mainf_commit_staged() {
  gf_git "$1" commit -q -m "$2" || return 1
  gf_git "$1" rev-parse HEAD
}

##
# Write each <path> in the work tree of <repo> with <content> (followed by LF),
# stage it, commit, and print the new commit OID. Used for ordinary file names
# only.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_mainf_commit_files() {
  local _repo="$1" _message="$2"
  shift 2

  while (($# >= 2)); do
    printf '%s\n' "$2" >"${_repo}/$1" || return 1
    gf_git "$_repo" add -- "$1" || return 1
    shift 2
  done
  _mainf_commit_staged "$_repo" "$_message"
}

##
# Register each <path> in the index of <repo> directly, as a regular file
# (100644) whose content is <content> followed by LF, commit, and print the new
# commit OID. Used for special file names (non-ASCII and the like), so they
# never pass through the work tree of the host file system.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_mainf_commit_index_files() {
  local _repo="$1" _message="$2" _blob
  shift 2

  while (($# >= 2)); do
    _blob="$(printf '%s\n' "$2" | gf_git "$_repo" hash-object -w --stdin)" || return 1
    gf_git "$_repo" update-index --add --cacheinfo "100644,${_blob},$1" || return 1
    shift 2
  done
  _mainf_commit_staged "$_repo" "$_message"
}

##
# Register every path listed in ${GF_TMP_ROOT}/paths.txt (each path terminated
# by NUL) in the index of <repo> directly, as regular files (100644) sharing
# one blob whose content is "doc" followed by LF, with a single
# "git update-index --index-info" call, commit, and print the new commit OID.
# Used for the fixtures with many paths, where one --cacheinfo call per path
# would be too slow. The paths must hold no LF, TAB or other character that
# --index-info would misread.
# Used by _mainf_build_paths_file (T-GCF-MAINF-12 / 21).
# Requires: <repo> was created by gf_init_repo and paths.txt exists.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_mainf_commit_index_paths_file() {
  local _repo="$1" _message="$2" _blob

  _blob="$(printf 'doc\n' | gf_git "$_repo" hash-object -w --stdin)" || return 1
  tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt" |
    awk -v blob="$_blob" '{ printf "100644 %s\t%s\n", blob, $0 }' |
    gf_git "$_repo" update-index --add --index-info || return 1
  _mainf_commit_staged "$_repo" "$_message"
}

# バイト数を指定した一覧 (DR-15)

##
# Write ${GF_TMP_ROOT}/paths.txt (each path terminated by NUL) with ASCII paths
# whose list, joined by LF with no trailing LF, is exactly <bytes> bytes. Each
# path is "dNN/f<index>", the index zero-padded so that the path is 100 bytes
# (101 with its LF), split into directories of 100 paths; one last path
# "z/x..." takes the remaining 10 to 110 bytes. Every path component stays
# within 255 bytes. Counted under LC_ALL=C, so awk pads and measures in bytes.
# Used by _mainf_run_list_of_bytes (T-GCF-MAINF-12 / 21).
# Requires: _mainf_setup has been called (BeforeEach); 10 <= <bytes> < 1010010
# (so that "dNN" keeps two digits and every padded path stays 100 bytes).
# @arg $1 bytes — byte count of the LF-joined list
# @return 0 on success, non-zero on failure (pipefail is set in a subshell,
#         so it does not leak to the caller)
_mainf_write_paths_of_bytes() {
  local LC_ALL=C
  local _count=$((($1 - 10) / 101)) _rest

  _rest=$(($1 - _count * 101))
  (
    set -o pipefail
    awk -v count="$_count" -v rest="$_rest" 'BEGIN {
      for (i = 0; i < count; i++) printf "d%02d/f%095d\n", int(i / 100), i
      last = "z/"
      while (length(last) < rest) last = last "x"
      print last
    }' | tr '\n' '\0' >"${GF_TMP_ROOT}/paths.txt"
  )
}

##
# Fixture self-check: the list in ${GF_TMP_ROOT}/paths.txt, joined by LF with
# no trailing LF, is exactly <bytes> bytes (counted under LC_ALL=C), checked
# before the fixture is built so that a wrong list never reaches the script.
# Used by _mainf_run_list_of_bytes (T-GCF-MAINF-12 / 21).
# Requires: _mainf_write_paths_of_bytes has written paths.txt.
# @arg $1 bytes — expected byte count
# @stderr the actual byte count when it differs
# @return 0 when it matches, 1 otherwise
_mainf_paths_have_bytes() {
  local _list
  _list="$(tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt")" || return 1
  local LC_ALL=C
  [ "${#_list}" -eq "$1" ] && return 0
  echo "paths.txt list is ${#_list} bytes, expected $1" >&2
  return 1
}

##
# Build ${GF_TMP_ROOT}/expected.txt from ${GF_TMP_ROOT}/paths.txt (each path
# terminated by NUL): the paths sorted with "LC_ALL=C sort -z", the byte order
# in which "git diff --name-only" prints them (DR-15), written one per line.
# The paths of _mainf_write_paths_of_bytes are plain ASCII, so git prints them
# unquoted. The single place where paths.txt is turned into the expected list.
# Used by _mainf_files_match_expected (T-GCF-MAINF-21).
# Requires: _mainf_write_paths_of_bytes has written paths.txt (through
# _mainf_run_list_of_bytes).
# @return 0 on success, non-zero when sort or tr fails (pipefail is set in a
#         subshell, so it does not leak to the caller)
_mainf_write_expected() {
  (
    set -o pipefail
    LC_ALL=C sort -z "${GF_TMP_ROOT}/paths.txt" | tr '\0' '\n' >"${GF_TMP_ROOT}/expected.txt"
  )
}

##
# Build ${GF_TMP_ROOT}/expected.txt (_mainf_write_expected) and compare the
# files output (_mainf_files_output, no trailing LF) with it by diff,
# appending one LF to match the line-terminated file.
# Used by T-GCF-MAINF-21.
# Requires: _mainf_run_list_of_bytes has written paths.txt and run the script.
# @stderr a message when expected.txt cannot be built, or the diff when they
#         differ
# @return 0 when they match, non-zero otherwise
_mainf_files_match_expected() {
  local _mainf_files
  _mainf_write_expected || {
    echo "expected.txt not built (from paths.txt)" >&2
    return 1
  }
  _mainf_files="$(_mainf_files_output)" || return 1
  diff "${GF_TMP_ROOT}/expected.txt" <(printf '%s\n' "$_mainf_files") >&2
}

# 所要時間の記録 (implementation.md §1.3)
# Informational only: the timings never decide a result, and nothing is
# written to the subject's stdout or stderr. Used by _mainf_run_list_of_bytes
# (T-GCF-MAINF-12 / 21).

##
# Store the current time in microseconds in the variable named <var>, read
# from EPOCHREALTIME with its (locale-dependent) decimal separator removed.
# @arg $1 var — name of the variable to set
# @return 0 always
_mainf_now_us() {
  printf -v "$1" '%s' "${EPOCHREALTIME//[!0-9]/}"
}

##
# Append one line with the fixture build time and the run time of <case> to
# the file named by GCF_FIXTURE_TIMING, only when that variable is set (the
# test run from Windows needs WSLENV=GCF_FIXTURE_TIMING/p, see
# implementation.md §1.3). Nothing happens when it is unset. A write failure is
# discarded so that the record never changes the result or the subject's
# stderr. Line format (fields separated by one TAB, times in seconds):
#   <case> fixture=<s.uuuuuu> run=<s.uuuuuu>
# @arg $1 case  — Test ID of the case (e.g. T-GCF-MAINF-12)
# @arg $2 start — time before building the fixture (_mainf_now_us)
# @arg $3 built — time after building it, before the run
# @arg $4 done  — time after the run
# @return 0 always
_mainf_record_timing() {
  [ -n "${GCF_FIXTURE_TIMING:-}" ] || return 0
  local _fixture=$(($3 - $2)) _run=$(($4 - $3))

  {
    printf '%s\tfixture=%d.%06d\trun=%d.%06d\n' "$1" \
      $((_fixture / 1000000)) $((_fixture % 1000000)) \
      $((_run / 1000000)) $((_run % 1000000)) >>"$GCF_FIXTURE_TIMING"
  } 2>/dev/null || :
}

##
# Run get-changed-files.sh with bash in <repo> (gf_run_in, so the test never
# changes its own cwd); the variables a case exported / unset reach the script
# as they are. T-GCF-MAINF-13 does not use it: it calls main with a failing
# write_multiline_output through its own helper (_mainf_run_write_fails /
# _mainf_main_with_failing_write), so the script run here is never altered.
# @arg $1 repo — repository to run the script in
# @stdout / @stderr the script's output
# @return the script's exit code
_mainf_run() {
  gf_run_in "$1" bash "$_MAINF_SCRIPT"
}

# fixture の組み立てと実行

##
# Create the fixture repository, let <builder> commit into it and set
# BEFORE_SHA / AFTER_SHA, and export both. A failure of either step is
# reported with _setup_failed, so it is detected inside the It. The single
# place where the fixtures create their repository.
# Requires: _mainf_setup has been called (BeforeEach).
# Sets: _MAINF_REPO — the fixture repository path.
# Exports: BEFORE_SHA / AFTER_SHA as set by <builder>.
# @arg $1 builder — a _mainf_build_* function, called as
#                   "<builder> <repo> <args...>"; it sets BEFORE_SHA /
#                   AFTER_SHA and returns non-zero on failure
# @arg $2.. args  — passed to <builder> after the repository path
# @stderr a setup-failure message
# @return 0 on success, _SETUP_FAILED (98) when the fixture setup fails
_mainf_build() {
  local _builder="$1"
  shift

  _MAINF_REPO="$(gf_init_repo mainf)" || _setup_failed mainf || return
  "$_builder" "$_MAINF_REPO" "$@" || _setup_failed mainf || return
  export BEFORE_SHA AFTER_SHA
}

##
# Build the fixture with _mainf_build and run the script in its repository
# (_mainf_run). The common skeleton of the _mainf_run_* fixture runners.
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $1 builder — see _mainf_build
# @arg $2.. args  — see _mainf_build
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_fixture() {
  _mainf_build "$@" || return
  _mainf_run "$_MAINF_REPO"
}

# fixture の builder (_mainf_build に渡す)

##
# Builder: before: a.sh (content "one", through the work tree) / after: each
# <path> <content> pair committed with <commit>.
# @arg $1 repo    — repository path
# @arg $2 commit  — _mainf_commit_files (ordinary names, through the work
#                   tree) or _mainf_commit_index_files (special names,
#                   registered in the index directly)
# @arg $3.. pairs — <path> <content> pairs of the after commit
# @return 0 on success, 1 on failure
_mainf_build_on_base() {
  local _repo="$1" _commit="$2"
  shift 2

  BEFORE_SHA="$(_mainf_commit_files "$_repo" before a.sh one)" || return 1
  AFTER_SHA="$("$_commit" "$_repo" after "$@")"
}

##
# Builder: before: old.sh / after: old.sh deleted and each <path> <content>
# pair added (through the work tree); with no pair, the after commit only
# deletes old.sh.
# @arg $1 repo    — repository path
# @arg $2.. pairs — <path> <content> pairs of the after commit (optional)
# @return 0 on success, 1 on failure
_mainf_build_delete_old() {
  local _repo="$1"
  shift

  BEFORE_SHA="$(_mainf_commit_files "$_repo" before old.sh old)" || return 1
  gf_git "$_repo" rm -q -- old.sh || return 1
  AFTER_SHA="$(_mainf_commit_files "$_repo" after "$@")"
}

##
# Builder: one commit (a.sh); BEFORE_SHA and AFTER_SHA are both that commit,
# so the two trees are the same.
# @arg $1 repo — repository path
# @return 0 on success, 1 on failure
_mainf_build_same_tree() {
  BEFORE_SHA="$(_mainf_commit_files "$1" only a.sh one)" || return 1
  AFTER_SHA="$BEFORE_SHA"
}

##
# Builder: one commit (a.sh); the variable named <var> (BEFORE_SHA or
# AFTER_SHA) is <value> and the other one is that commit. The resulting
# AFTER_SHA is also written to ${GF_TMP_ROOT}/after.txt for
# _mainf_ends_with_list_error, since the It cannot see the OID created inside
# the fixture.
# @arg $1 repo  — repository path
# @arg $2 var   — BEFORE_SHA or AFTER_SHA, the variable set to <value>
# @arg $3 value — value of <var>
# @return 0 on success, 1 on failure (including an unknown <var>)
_mainf_build_with_sha() {
  local _oid

  _oid="$(_mainf_commit_files "$1" only a.sh one)" || return 1
  case "$2" in
  BEFORE_SHA) BEFORE_SHA="$3" AFTER_SHA="$_oid" ;;
  AFTER_SHA) BEFORE_SHA="$_oid" AFTER_SHA="$3" ;;
  *) return 1 ;;
  esac
  printf '%s\n' "$AFTER_SHA" >"${GF_TMP_ROOT}/after.txt"
}

##
# Builder: before: base.md / after: every path of ${GF_TMP_ROOT}/paths.txt
# added (registered in the index with one --index-info call,
# _mainf_commit_index_paths_file).
# Requires: paths.txt exists.
# @arg $1 repo — repository path
# @return 0 on success, 1 on failure
_mainf_build_paths_file() {
  BEFORE_SHA="$(_mainf_commit_files "$1" before base.md base)" || return 1
  AFTER_SHA="$(_mainf_commit_index_paths_file "$1" after)"
}

# fixture runner (When call から呼ぶ)

##
# before: a.sh / after: a.sh modified and b.md added; run the script. On
# success the files output is _MAINF_MODIFY_ADD_FILES.
# Used by T-GCF-MAINF-01, 04, 09, 10, 14, 17 and 18.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_modify_add() {
  _mainf_run_fixture _mainf_build_on_base _mainf_commit_files a.sh two b.md doc
}

##
# before: old.sh / after: old.sh deleted and new.sh added; run the script.
# Used by T-GCF-MAINF-02.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_delete_add() {
  _mainf_run_fixture _mainf_build_delete_old new.sh new
}

##
# before: old.sh / after: old.sh deleted and nothing else changed; run the
# script.
# Used by T-GCF-MAINF-06.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_delete_only() {
  _mainf_run_fixture _mainf_build_delete_old
}

##
# before: a.sh / after: each <path> added with the content "doc" (through the
# work tree); run the script.
# Used by T-GCF-MAINF-19 (a file named EOF).
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $@ paths — ordinary file names added by the after commit
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_add_files() {
  local _path
  local -a _pairs=()

  for _path in "$@"; do
    _pairs+=("$_path" doc)
  done
  _mainf_run_fixture _mainf_build_on_base _mainf_commit_files "${_pairs[@]}"
}

##
# before: a.sh / after: <path> added with the content "doc" (registered in the
# index directly); run the script.
# Used by T-GCF-MAINF-03 (non-ASCII path) / 20 (quoted path).
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $1 path — special file name added by the after commit
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_add_index_file() {
  _mainf_run_fixture _mainf_build_on_base _mainf_commit_index_files "$1" doc
}

##
# One commit (a.sh) used as both BEFORE_SHA and AFTER_SHA; run the script.
# Used by T-GCF-MAINF-05.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_same_tree() {
  _mainf_run_fixture _mainf_build_same_tree
}

##
# One commit (a.sh) as one side and <value> as <var> (the other side); run the
# script (fixture: _mainf_build_with_sha).
# Used by T-GCF-MAINF-07, 15 and 22 (empty BEFORE_SHA), T-GCF-MAINF-08 (empty
# AFTER_SHA) and T-GCF-MAINF-11 and 16 (BEFORE_SHA=_MISSING_SHA).
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $1 var   — BEFORE_SHA or AFTER_SHA, the variable exported as <value>
# @arg $2 value — value exported as <var>
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_with_sha() {
  _mainf_run_fixture _mainf_build_with_sha "$1" "$2"
}

##
# Write paths.txt with ASCII paths whose LF-joined list is exactly <bytes>
# bytes and check that count before running; then build the fixture with
# _mainf_build_paths_file and run the script. paths.txt is kept, so a case can
# build its expected list from it afterwards (_mainf_files_match_expected). The fixture build time and the
# run time are recorded for <case> with _mainf_record_timing (only when
# GCF_FIXTURE_TIMING is set).
# Used by T-GCF-MAINF-12 (120001 bytes) and T-GCF-MAINF-21 (120000 bytes).
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $1 case  — Test ID of the case, for the timing record
# @arg $2 bytes — byte count of the LF-joined list
# @stdout / @stderr the script's output, or a setup-failure message
# @return the script's exit code, or _SETUP_FAILED (98)
_mainf_run_list_of_bytes() {
  local _start _built _done _status=0

  _mainf_now_us _start
  _mainf_write_paths_of_bytes "$2" || _setup_failed mainf || return
  _mainf_paths_have_bytes "$2" || _setup_failed mainf || return
  _mainf_build _mainf_build_paths_file || return
  _mainf_now_us _built
  _mainf_run "$_MAINF_REPO" || _status=$?
  _mainf_now_us _done
  _mainf_record_timing "$1" "$_start" "$_built" "$_done"
  return "$_status"
}

##
# Source get-changed-files.sh in a subshell, replace write_multiline_output
# with a stub that returns 2 (a write failure), and call main. A write failure
# cannot be caused through the file system once validate_output_file has
# accepted GITHUB_OUTPUT, so R-DIF-016 is reached by replacing the function
# (implementation.md §1.3). Sourcing does not run main (the script's guard),
# and the subshell keeps the script's "set -euo pipefail" and its definitions
# from leaking into the ShellSpec shell.
# Used by _mainf_run_write_fails (T-GCF-MAINF-13), through gf_run_in.
# @stdout / @stderr main's output
# @return main's exit code
_mainf_main_with_failing_write() {
  (
    # shellcheck source=/dev/null
    . "$_MAINF_SCRIPT" || exit
    write_multiline_output() { return 2; }
    main
  )
}

##
# The fixture of _mainf_run_modify_add (before: a.sh / after: a.sh modified
# and b.md added), but call main in the repository with write_multiline_output
# failing (_mainf_main_with_failing_write). Kept apart from _mainf_run, which
# executes the script unchanged.
# Used by T-GCF-MAINF-13.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr main's output, or a setup-failure message
# @return main's exit code, or _SETUP_FAILED (98)
_mainf_run_write_fails() {
  _mainf_build _mainf_build_on_base _mainf_commit_files a.sh two b.md doc || return
  gf_run_in "$_MAINF_REPO" _mainf_main_with_failing_write
}

##
# Print the value of the multiline files output in the output file: the lines
# after "files<<<delimiter>" up to (not including) the line equal to the
# delimiter. Lines are read with IFS= and read -r, so spaces at both ends and
# backslashes are kept. Reads the file named by GITHUB_OUTPUT, so a case that
# exports another output path (T-GCF-MAINF-18) reads that file.
# Used by T-GCF-MAINF-01 .. 03, 05, 06 and 18 .. 20, and by
# _mainf_files_match_expected (T-GCF-MAINF-21).
# Requires: _mainf_setup has been called (BeforeEach) or GITHUB_OUTPUT names
# the output file.
# @stdout the files lines separated by LF, with no trailing LF
# @return 0 when a files<< line is found, 1 otherwise
_mainf_files_output() {
  local _mainf_line _mainf_delim="" _mainf_found=0 _mainf_out="" _mainf_sep=""
  while IFS= read -r _mainf_line; do
    if [ "$_mainf_found" -eq 0 ]; then
      if [[ $_mainf_line == 'files<<'* ]]; then
        _mainf_delim="${_mainf_line#files<<}"
        _mainf_found=1
      fi
      continue
    fi
    [ "$_mainf_line" = "$_mainf_delim" ] && break
    _mainf_out+="${_mainf_sep}${_mainf_line}"
    _mainf_sep=$'\n'
  done <"$GITHUB_OUTPUT"
  [ "$_mainf_found" -eq 1 ] || return 1
  printf '%s' "$_mainf_out"
}

##
# Print the delimiter of the multiline files output (what follows "files<<")
# in the output file. Reads the file named by GITHUB_OUTPUT, the same file as
# _mainf_files_output.
# Used by T-GCF-MAINF-19.
# Requires: _mainf_setup has been called (BeforeEach) or GITHUB_OUTPUT names
# the output file.
# @stdout the delimiter
# @return 0 when a files<< line is found, 1 otherwise
_mainf_delimiter() {
  local _mainf_line
  while IFS= read -r _mainf_line; do
    if [[ $_mainf_line == 'files<<'* ]]; then
      printf '%s' "${_mainf_line#files<<}"
      return 0
    fi
  done <"$GITHUB_OUTPUT"
  return 1
}

##
# Write _MAINF_EXISTING_LINE (followed by LF) to the output file named by
# GITHUB_OUTPUT, as content that was there before the script runs.
# Used by T-GCF-MAINF-04 and 22.
# Requires: _mainf_setup has been called (BeforeEach).
# @return 0 on success, non-zero when the write fails
_mainf_write_existing_line() {
  printf '%s\n' "$_MAINF_EXISTING_LINE" >"$GITHUB_OUTPUT"
}

##
# Print the number of entries (dot files included) in the directory
# <dir>, so a case can check that nothing was written into it.
# Used by T-GCF-MAINF-10 and 16.
# @arg $1 dir — directory to count the entries of
# @stdout the number of entries in <dir>
# @return 0
_mainf_dir_entries() {
  (
    shopt -s nullglob dotglob
    local -a _mainf_entries=("$1"/*)
    printf '%s' "${#_mainf_entries[@]}"
  )
}

##
# Create the empty directory ${GF_TMP_ROOT}/outdir and export it as
# GITHUB_OUTPUT, so the output path is a directory (R-DIF-013).
# Used by T-GCF-MAINF-10 and 16.
# Requires: _mainf_setup has been called (BeforeEach).
# Sets: _MAINF_DIR_OUTPUT — the directory path.
# Exports: GITHUB_OUTPUT="$_MAINF_DIR_OUTPUT".
# @return 0 on success, 1 when the directory cannot be created
_mainf_export_dir_output() {
  _MAINF_DIR_OUTPUT="${GF_TMP_ROOT}/outdir"
  mkdir "$_MAINF_DIR_OUTPUT" || return 1
  export GITHUB_OUTPUT="$_MAINF_DIR_OUTPUT"
}

# エラー出力の確認

##
# Satisfy-matcher for "The entire stderr should satisfy
# _mainf_ends_with_list_error <before>": the last line of the subject (one
# trailing LF ignored; ShellSpec stores the subject in the variable named after
# the matcher) equals the R-DIF-002 error whose value is <before>..<after>,
# with the after OID read from ${GF_TMP_ROOT}/after.txt (written by
# _mainf_build_with_sha). git's own output may precede that line (R-DIF-014),
# so only the last line is compared, not the whole stderr.
# Used by T-GCF-MAINF-11.
# Requires: _mainf_build_with_sha has written after.txt.
# @arg $1 before — expected before side of the error value
# @stderr the expected and the actual last line when they differ, or a
#         message when after.txt cannot be read
# @return 0 when it matches, 1 otherwise
_mainf_ends_with_list_error() {
  local _mainf_text="${_mainf_ends_with_list_error%$'\n'}" _mainf_last _mainf_after _mainf_expected

  _mainf_after="$(<"${GF_TMP_ROOT}/after.txt")" || {
    echo "after.txt not readable (written by _mainf_build_with_sha)" >&2
    return 1
  }
  _mainf_expected="::error::files: failed to list changed files (got: '${1}..${_mainf_after}')"
  _mainf_last="${_mainf_text##*$'\n'}"
  [ "$_mainf_last" = "$_mainf_expected" ] && return 0
  printf 'expected last line: %q\nactual last line:   %q\n' "$_mainf_expected" "$_mainf_last" >&2
  return 1
}

# --- テスト本体 ---

Describe 'get-changed-files.sh'
  BeforeEach '_mainf_setup'
  AfterEach 'gf_cleanup'

  ##
  # main: read BEFORE_SHA / AFTER_SHA / GITHUB_OUTPUT, check them, list the
  # files changed between the two commits (list_changed_files) and write them
  # as the multiline files output to GITHUB_OUTPUT (no count output).
  # Scenarios:
  #   normal (the changed files are written, exit 0 with an empty stderr):
  #     modified and added files are written to the files output, and nothing
  #     else is written (no count output); a deleted file is left out of the
  #     files output; a non-ASCII path is written as is; a line already in
  #     the output file is kept and the files output is appended after it;
  #     the same tree on both sides writes an empty files output; a diff that
  #     only deletes files writes an empty files output.
  #   error (a step fails: non-zero exit, the error on stderr, and nothing
  #     written): an empty BEFORE_SHA; an empty AFTER_SHA; an empty
  #     GITHUB_OUTPUT; a GITHUB_OUTPUT that is a directory; a failure of git
  #     diff (git's own output may precede the error line); a list over the
  #     120000-byte limit (120001 bytes); a failure to write the files output
  #     (only the error is checked).
  #   edge (boundaries of the check order, the inputs and the output file):
  #     when several checks fail at once only the first in the check order is
  #     reported (an empty BEFORE_SHA and an empty GITHUB_OUTPUT report only
  #     BEFORE_SHA; a GITHUB_OUTPUT that is a directory and a BEFORE_SHA
  #     missing from the repository report only GITHUB_OUTPUT, with no git
  #     output); an unset GITHUB_OUTPUT is reported like an empty one; a
  #     missing GITHUB_OUTPUT whose parent directory is writable is created
  #     and written; a path equal to the whole line EOF makes the delimiter
  #     EOF_1; a quoted path is written as is; a list of exactly 120000 bytes
  #     is written whole; a check failure leaves a line already in the output
  #     file unchanged.
  Describe 'main'
    # Cases where the changed files are written to the output file
    Context 'When: 正常系'
      It '[Normal] T-GCF-MAINF-01: 変更と追加のファイルを files に書く'
        When call _mainf_run_modify_add
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The result of function _mainf_files_output should equal "$_MAINF_MODIFY_ADD_FILES"
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_MODIFY_ADD_BLOCK"
      End

      It '[Normal] T-GCF-MAINF-02: 削除されたファイルは files に含めない'
        When call _mainf_run_delete_add
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_output should equal 'new.sh'
      End

      It '[Normal] T-GCF-MAINF-03: 非 ASCII 文字を含むパスをそのまま書く'
        When call _mainf_run_add_index_file 'docs/日本語.md'
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_output should equal 'docs/日本語.md'
      End

      It '[Normal] T-GCF-MAINF-04: 出力ファイルの既存の内容を残して追記する'
        _mainf_write_existing_line
        When call _mainf_run_modify_add
        The status should equal 0
        The stderr should equal ''
        The line 1 of contents of file "$GITHUB_OUTPUT" should equal "$_MAINF_EXISTING_LINE"
        The contents of file "$GITHUB_OUTPUT" should equal "${_MAINF_EXISTING_LINE}"$'\n'"${_MAINF_MODIFY_ADD_BLOCK}"
      End

      It '[Normal] T-GCF-MAINF-05: 同じツリーなら空の files を書く'
        When call _mainf_run_same_tree
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_output should equal ''
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_EMPTY_BLOCK"
      End

      It '[Normal] T-GCF-MAINF-06: 削除だけの差分は空の files を書く'
        When call _mainf_run_delete_only
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_output should equal ''
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_EMPTY_BLOCK"
      End
    End

    # Cases where a step fails. Each checks, in this order: a non-zero exit;
    # the error on stderr, as exactly one ::error:: line, except
    # T-GCF-MAINF-11, where git's own output may precede the ::error:: line
    # (R-DIF-014); and the output file prepared by _mainf_setup
    # (_MAINF_OUTPUT) left empty, also when a case points GITHUB_OUTPUT
    # elsewhere (T-GCF-MAINF-09 / 10), except T-GCF-MAINF-13 (see its comment)
    Context 'When: 異常系'
      It '[Error] T-GCF-MAINF-07: BEFORE_SHA が空'
        When call _mainf_run_with_sha BEFORE_SHA ''
        The status should not equal 0
        The stderr should equal "$_MAINF_ERR_BEFORE_EMPTY"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      It '[Error] T-GCF-MAINF-08: AFTER_SHA が空'
        When call _mainf_run_with_sha AFTER_SHA ''
        The status should not equal 0
        The stderr should equal '::error::AFTER_SHA: value must not be empty'
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      It '[Error] T-GCF-MAINF-09: GITHUB_OUTPUT が空'
        export GITHUB_OUTPUT=''
        When call _mainf_run_modify_add
        The status should not equal 0
        The stderr should equal "$_MAINF_ERR_OUTPUT_EMPTY"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      It '[Error] T-GCF-MAINF-10: GITHUB_OUTPUT がディレクトリ'
        _mainf_export_dir_output
        When call _mainf_run_modify_add
        The status should not equal 0
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '${_MAINF_DIR_OUTPUT}')"
        The value "$(_mainf_dir_entries "$_MAINF_DIR_OUTPUT")" should equal 0
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      It '[Error] T-GCF-MAINF-11: git diff の失敗'
        When call _mainf_run_with_sha BEFORE_SHA "$_MISSING_SHA"
        The status should not equal 0
        The entire stderr should satisfy _mainf_ends_with_list_error "$_MISSING_SHA"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      It '[Error] T-GCF-MAINF-12: 120001 バイトの一覧'
        When call _mainf_run_list_of_bytes T-GCF-MAINF-12 120001
        The status should not equal 0
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120001')"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      # A failure after writing has started may leave output behind (spec
      # index §3.2), so only the error is checked and the output file is not
      # (_mainf_run_write_fails, apart from _mainf_run)
      It '[Error] T-GCF-MAINF-13: files の書き込みの失敗'
        When call _mainf_run_write_fails
        The status should not equal 0
        The stderr should equal "::error::files: failed to write (got: '${GITHUB_OUTPUT}')"
      End
    End

    # Boundary cases: several checks fail at once and only the first in the
    # check order (R-DIF-010 .. R-DIF-014) is reported (T-GCF-MAINF-15 / 16);
    # GITHUB_OUTPUT is unset rather than empty (17); the output file does not
    # exist yet (18) or already has content when a check fails (22); a path
    # collides with the default delimiter (19) or is quoted by git (20); the
    # list is exactly at the 120000-byte limit (21)
    Context 'When: エッジケース'
      It '[Edge] T-GCF-MAINF-15: BEFORE_SHA と GITHUB_OUTPUT がともに空なら BEFORE_SHA だけを報告する'
        export GITHUB_OUTPUT=''
        When call _mainf_run_with_sha BEFORE_SHA ''
        The status should not equal 0
        The stderr should equal "$_MAINF_ERR_BEFORE_EMPTY"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      # R-DIF-013 is checked before git diff runs (R-DIF-014), so the
      # missing BEFORE_SHA never reaches git and stderr holds no git output
      It '[Edge] T-GCF-MAINF-16: 出力先の検証は git diff より先に行う'
        _mainf_export_dir_output
        When call _mainf_run_with_sha BEFORE_SHA "$_MISSING_SHA"
        The status should not equal 0
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '${_MAINF_DIR_OUTPUT}')"
        The value "$(_mainf_dir_entries "$_MAINF_DIR_OUTPUT")" should equal 0
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      # An unset GITHUB_OUTPUT is read as empty (no "unbound variable" under
      # set -u) and reported in the empty form, like T-GCF-MAINF-09
      It '[Edge] T-GCF-MAINF-17: GITHUB_OUTPUT が未設定'
        unset GITHUB_OUTPUT
        When call _mainf_run_modify_add
        The status should not equal 0
        The stderr should equal "$_MAINF_ERR_OUTPUT_EMPTY"
        The contents of file "$_MAINF_OUTPUT" should equal ''
      End

      # A missing output file is accepted when its parent directory is
      # writable (validate_output_file), and the write creates it
      It '[Edge] T-GCF-MAINF-18: 存在しない出力先は親ディレクトリが書ければ作って書く'
        export GITHUB_OUTPUT="${GF_TMP_ROOT}/new-output"
        When call _mainf_run_modify_add
        The status should equal 0
        The stderr should equal ''
        The path "$GITHUB_OUTPUT" should be file
        The result of function _mainf_files_output should equal "$_MAINF_MODIFY_ADD_FILES"
        The contents of file "$GITHUB_OUTPUT" should equal "$_MAINF_MODIFY_ADD_BLOCK"
      End

      # A path equal to the whole line EOF collides with the default
      # delimiter, so write_multiline_output picks EOF_1 (spec diff §5)
      It '[Edge] T-GCF-MAINF-19: 行全体が EOF のパスがあれば区切り文字を EOF_1 にする'
        When call _mainf_run_add_files EOF
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_delimiter should equal 'EOF_1'
        The result of function _mainf_files_output should equal 'EOF'
        The contents of file "$GITHUB_OUTPUT" should equal "$_MAINF_EOF_BLOCK"
      End

      # git diff always quotes a path holding a double quote, even with
      # core.quotePath off; main writes the quoted form as is, and validating
      # the path is left to the filter stage (R-DIF-004)
      It '[Edge] T-GCF-MAINF-20: 引用表記のパスはそのまま書く'
        When call _mainf_run_add_index_file 'a"b.sh'
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_output should equal '"a\"b.sh"'
      End

      # A list of exactly the limit (R-DIF-003 rejects only above 120000
      # bytes) is written whole, in git's byte order
      It '[Edge] T-GCF-MAINF-21: 120000 バイトちょうどの一覧を書く'
        When call _mainf_run_list_of_bytes T-GCF-MAINF-21 120000
        The status should equal 0
        The stderr should equal ''
        The result of function _mainf_files_match_expected should be successful
      End

      # A failure in the checks (Step 1-4) writes nothing, so a line already
      # in the output file stays the only content (spec diff)
      It '[Edge] T-GCF-MAINF-22: 検証で失敗しても出力ファイルの既存の内容を変えない'
        _mainf_write_existing_line
        When call _mainf_run_with_sha BEFORE_SHA ''
        The status should not equal 0
        The stderr should equal "$_MAINF_ERR_BEFORE_EMPTY"
        The contents of file "$GITHUB_OUTPUT" should equal "$_MAINF_EXISTING_LINE"
      End
    End
  End
End
