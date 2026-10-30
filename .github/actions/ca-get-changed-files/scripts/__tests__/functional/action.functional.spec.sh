#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/__tests__/functional/action.functional.spec.sh
# @(#) : functional tests for the action.yml step chain
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Functional test suite for the action.yml step chain
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: ca-get-changed-files/action.yml (resolve-sha.sh -> get-changed-files.sh -> filter-files.sh)

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# Actions directory of the repository; the scripts are run from a copy
# (_runf_install_copy). スクリプトはコピーから実行する。対象は Include しない
# Used by _runf_install_copy.
_RUNF_ACTIONS_SRC="${SHELLSPEC_PROJECT_ROOT}/.github/actions"

# --- ヘルパー ---
# Real git repository fixtures (gf_setup / gf_cleanup / gf_init_repo / gf_git / gf_run_in)
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"

# --- 内部ヘルパー ---
# 定数
# Exit code of _setup_failed when a fixture or the copy cannot be built inside
# an It; no T-GCF-RUNF case expects it; used by _setup_failed
_SETUP_FAILED=98
# files output of the _runf_build_push_modify_add fixture (a.sh modified, b.md
# added); used by T-GCF-RUNF-01
_RUNF_A_SH_B_MD=$'a.sh\nb.md'
# files output of the _runf_build_pr_two_point fixture (two-point diff
# base..head: a.sh modified and b.md added on head, shared.sh changed on base
# only; base-only.sh is not included); used by T-GCF-RUNF-02
_RUNF_PR_FILES=$'a.sh\nb.md\nshared.sh'
# files output of the _runf_build_single_commit fixture (a.sh / b.sh, diffed
# against the empty tree) and of the _runf_build_three_commits_ab fixture;
# used by T-GCF-RUNF-05, T-GCF-RUNF-28
_RUNF_A_SH_B_SH=$'a.sh\nb.sh'
# Multiline pattern input: include src/** and exclude src/gen/**; used by
# T-GCF-RUNF-06
_RUNF_PATTERN_SRC_EXCL_GEN=$'src/**\n!src/gen/**'
# files output of the _runf_build_push_files fixture with a.sh / dir/b.md added
# and an empty pattern (every file returned); used by T-GCF-RUNF-07
_RUNF_A_SH_DIR_B_MD=$'a.sh\ndir/b.md'
# GITHUB_BEFORE_SHA of a push that creates a branch (40 zeros, not a commit);
# used by _runf_build_zero_before (T-GCF-RUNF-23)
_RUNF_ZERO_SHA="0000000000000000000000000000000000000000"

# 関数

##
# Report a fixture setup failure on stderr and return _SETUP_FAILED, so the
# failure is detected inside the It that builds the fixture or the copy.
# Used by every case and _runf_run_paths.
# @arg $1 name — name of the failed fixture (for the message)
# @stderr "<name> fixture setup failed"
# @return _SETUP_FAILED (98)
_setup_failed() {
  echo "$1 fixture setup failed" >&2
  return "$_SETUP_FAILED"
}

##
# Prepare the per-example environment: the fixture root (gf_setup), the paths
# of the three step output files (not created: _runf_chain creates each one
# right before its step), the defaults of the case and an environment isolated
# from the host (implementation.md §1.3). Unsets every variable the scripts or
# their libraries read: GITHUB_OUTPUT, GITHUB_ACTION_PATH, BEFORE_SHA /
# AFTER_SHA, the old PATTERN, the GITHUB_* event variables, every INPUT_* and
# every *_LIB_LOADED load guard (so an inherited guard never makes a library
# source a no-op). The event variables are then set again, not exported, by
# _runf_event_push; _runf_chain passes them to the resolve-sha step only.
# Used by every case (BeforeEach).
# Sets: _RUNF_OUT_RS / _RUNF_OUT_GCF / _RUNF_OUT_FF — output file paths of the
#       resolve-sha / get-changed-files / filter-files steps;
#       _RUNF_COMMIT_COUNT="1" — the commit-count input;
#       _RUNF_PATTERN="" — the pattern input;
#       the push event of _runf_event_push with empty before / after.
# @return 0 on success, 1 when gf_setup fails
_runf_setup() {
  local _runf_var

  gf_setup || return 1
  _RUNF_OUT_RS="${GF_TMP_ROOT}/out-resolve-sha"
  _RUNF_OUT_GCF="${GF_TMP_ROOT}/out-get-changed-files"
  _RUNF_OUT_FF="${GF_TMP_ROOT}/out-filter-files"
  unset GITHUB_OUTPUT GITHUB_ACTION_PATH BEFORE_SHA AFTER_SHA PATTERN \
    GITHUB_EVENT_NAME GITHUB_REF GITHUB_EVENT_DELETED \
    GITHUB_BEFORE_SHA GITHUB_AFTER_SHA GITHUB_BASE_SHA GITHUB_HEAD_SHA
  for _runf_var in $(compgen -e INPUT_) $(compgen -v | grep '_LIB_LOADED$'); do
    unset "$_runf_var"
  done
  _RUNF_COMMIT_COUNT="1"
  _RUNF_PATTERN=""
  _runf_event_push '' ''
  return 0
}

##
# Copy ca-get-changed-files, _ca-resolve-sha, _ca-filter-files and _libs from
# the repository as siblings under ${GF_TMP_ROOT}/actions (outside any git
# repository), the layout the libraries resolve "<actions>/_libs" from, and
# export GITHUB_ACTION_PATH as the copied ca-get-changed-files, as the runner
# does for a composite Action. The chain runs these copies, never the
# repository scripts. The copy is placed outside the fixture repository (the
# working directory of the steps), which never has a .github/actions: the
# internal Actions must be found from GITHUB_ACTION_PATH, not from the working
# directory, as when the Action is used from another repository (AC-014).
# Called inside the It, so a failure is detected there.
# Used by every case.
# Requires: _runf_setup has been called (BeforeEach).
# Exports: GITHUB_ACTION_PATH="${GF_TMP_ROOT}/actions/ca-get-changed-files".
# @return 0 on success, 1 when a copy step fails
_runf_install_copy() {
  local _runf_dir="${GF_TMP_ROOT}/actions"

  mkdir -p "$_runf_dir" || return 1
  cp -R "${_RUNF_ACTIONS_SRC}/"{ca-get-changed-files,_ca-resolve-sha,_ca-filter-files,_libs} \
    "${_runf_dir}/" || return 1
  export GITHUB_ACTION_PATH="${_runf_dir}/ca-get-changed-files"
}

##
# Commit what is staged in the index of <repo> and print the new commit OID.
# The single place where the fixtures create a commit.
# Used by _runf_commit_files, _runf_commit_index_files and
# _runf_commit_index_paths_file.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_runf_commit_staged() {
  gf_git "$1" commit -q -m "$2" || return 1
  gf_git "$1" rev-parse HEAD
}

##
# Write each <path> in the work tree of <repo> with <content> (followed by LF),
# stage it, commit, and print the new commit OID. Used for ordinary file names
# only.
# Used by every builder (_runf_build_*), so by every case: for all of the
# commits of most builders, and for the base.txt commit of
# _runf_build_push_index_paths and _runf_build_push_paths_file.
# Requires: <repo> was created by gf_init_repo; the parent directory of each
# <path> exists.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_runf_commit_files() {
  local _repo="$1" _message="$2"
  shift 2

  while (($# >= 2)); do
    printf '%s\n' "$2" >"${_repo}/$1" || return 1
    gf_git "$_repo" add -- "$1" || return 1
    shift 2
  done
  _runf_commit_staged "$_repo" "$_message"
}

##
# Register each <path> in the index of <repo> directly, as a regular file
# (100644) whose content is <content> followed by LF, commit, and print the new
# commit OID. Used for special file names (a double quote and the like), so
# they never pass through the work tree of the host file system.
# Used by _runf_build_push_index_paths (T-GCF-RUNF-13, T-GCF-RUNF-22).
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_runf_commit_index_files() {
  local _repo="$1" _message="$2" _blob
  shift 2

  while (($# >= 2)); do
    _blob="$(printf '%s\n' "$2" | gf_git "$_repo" hash-object -w --stdin)" || return 1
    gf_git "$_repo" update-index --add --cacheinfo "100644,${_blob},$1" || return 1
    shift 2
  done
  _runf_commit_staged "$_repo" "$_message"
}

##
# Register every path listed in ${GF_TMP_ROOT}/paths.txt (each path terminated
# by NUL) in the index of <repo> directly, as regular files (100644) sharing
# one blob whose content is "doc" followed by LF, with a single
# "git update-index --index-info" call, commit, and print the new commit OID.
# Used for the fixtures with many paths, where one --cacheinfo call per path
# would be too slow. The paths must hold no LF, TAB or other character that
# --index-info would misread.
# Used by _runf_build_push_paths_file (T-GCF-RUNF-14, T-GCF-RUNF-15,
# T-GCF-RUNF-24, T-GCF-RUNF-25).
# Requires: <repo> was created by gf_init_repo and paths.txt exists.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_runf_commit_index_paths_file() {
  local _repo="$1" _message="$2" _blob

  _blob="$(printf 'doc\n' | gf_git "$_repo" hash-object -w --stdin)" || return 1
  tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt" |
    awk -v blob="$_blob" '{ printf "100644 %s\t%s\n", blob, $0 }' |
    gf_git "$_repo" update-index --add --index-info || return 1
  _runf_commit_staged "$_repo" "$_message"
}

# イベント (resolve-sha の step の env、implementation.md §1.3 RUNF)
# Each sets all seven event variables the resolve-sha step reads (not
# exported; _runf_chain passes them to that step only), the unused side empty.
# GITHUB_REF / GITHUB_EVENT_DELETED are push values: set by _runf_event_push
# only, empty in the other events.

##
# Set a push event on refs/heads/main (not a deletion) from <before> to
# <after>; the pull_request SHAs are empty.
# Used by _runf_setup (the default event), _runf_build_push_modify_add
# (T-GCF-RUNF-01), _runf_build_push_files (T-GCF-RUNF-06, T-GCF-RUNF-07,
# T-GCF-RUNF-08, T-GCF-RUNF-09, T-GCF-RUNF-16, T-GCF-RUNF-17, T-GCF-RUNF-18,
# T-GCF-RUNF-20, T-GCF-RUNF-26, T-GCF-RUNF-27), _runf_build_push_index_paths
# (T-GCF-RUNF-13, T-GCF-RUNF-22), _runf_build_push_paths_file (T-GCF-RUNF-14,
# T-GCF-RUNF-15, T-GCF-RUNF-24, T-GCF-RUNF-25) and _runf_build_zero_before
# (T-GCF-RUNF-23).
# @arg $1 before — GITHUB_BEFORE_SHA
# @arg $2 after  — GITHUB_AFTER_SHA
# @return 0 always
_runf_event_push() {
  GITHUB_EVENT_NAME=push GITHUB_REF=refs/heads/main GITHUB_EVENT_DELETED=false
  GITHUB_BEFORE_SHA="$1" GITHUB_AFTER_SHA="$2" GITHUB_BASE_SHA='' GITHUB_HEAD_SHA=''
}

##
# Set a pull_request event with <base> and <head>; the push values
# (GITHUB_REF / GITHUB_EVENT_DELETED / GITHUB_BEFORE_SHA / GITHUB_AFTER_SHA)
# are empty.
# Used by _runf_build_pr_two_point (T-GCF-RUNF-02).
# @arg $1 base — GITHUB_BASE_SHA
# @arg $2 head — GITHUB_HEAD_SHA
# @return 0 always
_runf_event_pr() {
  GITHUB_EVENT_NAME=pull_request GITHUB_REF='' GITHUB_EVENT_DELETED=''
  GITHUB_BEFORE_SHA='' GITHUB_AFTER_SHA='' GITHUB_BASE_SHA="$1" GITHUB_HEAD_SHA="$2"
}

##
# Set an event other than push / pull_request (workflow_dispatch); the push
# values (GITHUB_REF / GITHUB_EVENT_DELETED / GITHUB_BEFORE_SHA /
# GITHUB_AFTER_SHA) and the pull_request SHAs are all empty.
# Used by _runf_build_head_n_recent (T-GCF-RUNF-03), _runf_build_two_commits
# (T-GCF-RUNF-04, T-GCF-RUNF-10, T-GCF-RUNF-11, T-GCF-RUNF-12,
# T-GCF-RUNF-29), _runf_build_single_commit (T-GCF-RUNF-05),
# _runf_build_empty_head (T-GCF-RUNF-21) and _runf_build_three_commits_ab
# (T-GCF-RUNF-19, T-GCF-RUNF-28).
# @return 0 always
_runf_event_other() {
  GITHUB_EVENT_NAME=workflow_dispatch GITHUB_REF='' GITHUB_EVENT_DELETED=''
  GITHUB_BEFORE_SHA='' GITHUB_AFTER_SHA='' GITHUB_BASE_SHA='' GITHUB_HEAD_SHA=''
}

# step の連鎖と出力の読み取り

##
# Run one step: create its output file empty (as the runner does), then run
# <script> with bash in <repo> (gf_run_in) with GITHUB_OUTPUT set to that file
# and each <name=value> passed to this step only (env).
# Used by _runf_chain.
# @arg $1 repo   — repository to run the step in
# @arg $2 output — output file of the step (GITHUB_OUTPUT)
# @arg $3 script — script path
# @arg $4.. vars — <name=value> pairs of the step env
# @stdout / @stderr the script's output
# @return the script's exit code, 1 when the output file cannot be created
_runf_step() {
  local _runf_repo="$1" _runf_out="$2" _runf_script="$3"
  shift 3

  : >"$_runf_out" || return 1
  gf_run_in "$_runf_repo" env GITHUB_OUTPUT="$_runf_out" "$@" bash "$_runf_script"
}

##
# Run the three steps of action.yml in their order from the copy
# (GITHUB_ACTION_PATH), each with its own output file, passing the outputs of
# a step to the env of the next one as action.yml does: (1) resolve-sha with
# the seven event variables, INPUT_COMMIT_COUNT = _RUNF_COMMIT_COUNT and
# INPUT_BEFORE_SHA / INPUT_AFTER_SHA empty, (2) get-changed-files with
# BEFORE_SHA / AFTER_SHA = the before_sha / after_sha of (1), (3) filter-files
# with INPUT_FILES = the files of (2) and INPUT_PATTERNS = _RUNF_PATTERN. A
# missing output is passed as empty, as the runner does. Stops at the first
# failing step, so the output files of the later steps are never created.
# Used by every case.
# Requires: _runf_install_copy has exported GITHUB_ACTION_PATH; an event is
# set (_runf_event_*).
# @arg $1 repo — repository to run the steps in
# @stdout / @stderr the output of the steps
# @return the exit code of the first failing step, or 0
_runf_chain() {
  local _runf_repo="$1" _runf_before _runf_after _runf_files

  _runf_step "$_runf_repo" "$_RUNF_OUT_RS" \
    "${GITHUB_ACTION_PATH}/../_ca-resolve-sha/scripts/resolve-sha.sh" \
    GITHUB_EVENT_NAME="$GITHUB_EVENT_NAME" GITHUB_REF="$GITHUB_REF" \
    GITHUB_EVENT_DELETED="$GITHUB_EVENT_DELETED" \
    GITHUB_BEFORE_SHA="$GITHUB_BEFORE_SHA" GITHUB_AFTER_SHA="$GITHUB_AFTER_SHA" \
    GITHUB_BASE_SHA="$GITHUB_BASE_SHA" GITHUB_HEAD_SHA="$GITHUB_HEAD_SHA" \
    INPUT_COMMIT_COUNT="$_RUNF_COMMIT_COUNT" INPUT_BEFORE_SHA= INPUT_AFTER_SHA= || return
  _runf_before="$(_runf_output "$_RUNF_OUT_RS" before_sha)" || :
  _runf_after="$(_runf_output "$_RUNF_OUT_RS" after_sha)" || :
  _runf_step "$_runf_repo" "$_RUNF_OUT_GCF" \
    "${GITHUB_ACTION_PATH}/scripts/get-changed-files.sh" \
    BEFORE_SHA="$_runf_before" AFTER_SHA="$_runf_after" || return
  _runf_files="$(_runf_gcf_files)" || :
  _runf_step "$_runf_repo" "$_RUNF_OUT_FF" \
    "${GITHUB_ACTION_PATH}/../_ca-filter-files/scripts/filter-files.sh" \
    INPUT_FILES="$_runf_files" INPUT_PATTERNS="$_RUNF_PATTERN"
}

##
# Print the value of the output <key> in the step output file <file>, read in
# the GitHub Actions format: a line "<key>=<value>" gives <value>; a line
# "<key><<<delimiter>" gives the lines after it up to (not including) the line
# equal to <delimiter>, read with IFS= and read -r and joined by LF. A line is
# the multiline form when it has "<<" and no "=" before it; the lines of the
# other multiline outputs are skipped, so a line inside one is never taken as
# a key. A multiline value whose <delimiter> line never comes before the end
# of the file (the last line may lack its LF) is rejected, as the runner
# rejects such a file: nothing is printed and 1 is returned when it is met
# before <key> is found, whichever output it belongs to. An empty value (e.g. "files=" when no file
# matches) and a missing key both print nothing; only the return code tells
# them apart (0 / 1).
# Used by _runf_chain, _runf_ff_files, _runf_ff_count, _runf_gcf_files,
# _runf_has_key and _runf_files_match_expected.
# @arg $1 file — step output file
# @arg $2 key  — output name
# @stdout the value with no trailing LF (nothing for an empty value or on
#         failure)
# @return 0 when <key> is found, even with an empty value; 1 when it is not,
#         <file> does not exist, or a multiline value reaches the end of the
#         file without its <delimiter> line
_runf_output() {
  local _runf_line _runf_head _runf_delim _runf_value _runf_sep

  [ -f "$1" ] || return 1
  while IFS= read -r _runf_line; do
    _runf_head="${_runf_line%%<<*}"
    if [[ $_runf_line != *'<<'* || $_runf_head == *=* ]]; then
      [[ $_runf_line == "$2="* ]] || continue
      printf '%s' "${_runf_line#"$2="}"
      return 0
    fi
    _runf_delim="${_runf_line#*<<}" _runf_value='' _runf_sep=''
    while :; do
      IFS= read -r _runf_line || [ "$_runf_line" = "$_runf_delim" ] || return 1
      [ "$_runf_line" = "$_runf_delim" ] && break
      _runf_value+="${_runf_sep}${_runf_line}"
      _runf_sep=$'\n'
    done
    [ "$_runf_head" = "$2" ] || continue
    printf '%s' "$_runf_value"
    return 0
  done <"$1"
  return 1
}

##
# Print the files output of the filter-files step (the files output of the
# Action). Used by T-GCF-RUNF-01, T-GCF-RUNF-02, T-GCF-RUNF-03,
# T-GCF-RUNF-04, T-GCF-RUNF-05, T-GCF-RUNF-06, T-GCF-RUNF-07,
# T-GCF-RUNF-08, T-GCF-RUNF-20, T-GCF-RUNF-23, T-GCF-RUNF-26,
# T-GCF-RUNF-27, T-GCF-RUNF-28 and T-GCF-RUNF-29.
# @stdout the files lines separated by LF, with no trailing LF
# @return 0 when the key is found, 1 otherwise
_runf_ff_files() {
  _runf_output "$_RUNF_OUT_FF" files
}

##
# Print the count output of the filter-files step (the count output of the
# Action). Used by T-GCF-RUNF-01, T-GCF-RUNF-06, T-GCF-RUNF-07,
# T-GCF-RUNF-08, T-GCF-RUNF-20, T-GCF-RUNF-24, T-GCF-RUNF-26 and
# T-GCF-RUNF-27.
# @stdout the count
# @return 0 when the key is found, 1 otherwise
_runf_ff_count() {
  _runf_output "$_RUNF_OUT_FF" count
}

##
# Succeed when the step output file <file> has the output <key>, even with an
# empty value, so a step that wrote its output (e.g. an empty files output) is
# told apart from one that did not.
# Used by T-GCF-RUNF-08, T-GCF-RUNF-09, T-GCF-RUNF-21 and
# _runf_no_public_outputs.
# @arg $1 file — step output file
# @arg $2 key  — output name
# @stdout nothing
# @return 0 when <key> is found, 1 when it is not or <file> does not exist
_runf_has_key() {
  _runf_output "$1" "$2" >/dev/null
}

##
# Print the files output of the get-changed-files step (the input of the
# filter-files step). Used by _runf_chain and T-GCF-RUNF-21.
# @stdout the files lines separated by LF, with no trailing LF
# @return 0 when the key is found, 1 otherwise
_runf_gcf_files() {
  _runf_output "$_RUNF_OUT_GCF" files
}

# fixture の builder (It の中で呼ぶ)

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# two commits, before: a.sh (content "one") / after: a.sh modified and b.md
# added, and set the push event from the first to the second. The files output
# of the chain is then _RUNF_A_SH_B_MD.
# Used by T-GCF-RUNF-01.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the push event.
# @return 0 on success, 1 on failure
_runf_build_push_modify_add() {
  local _runf_before _runf_after

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_before="$(_runf_commit_files "$_RUNF_REPO" before a.sh one)" || return 1
  _runf_after="$(_runf_commit_files "$_RUNF_REPO" after a.sh two b.md doc)" || return 1
  _runf_event_push "$_runf_before" "$_runf_after"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with a
# pull_request history: the fork point (shared.sh / a.sh) on main; on the
# branch head, a.sh modified and b.md added (= head); back on main, shared.sh
# modified and base-only.sh added (= base). Sets the pull_request event from
# base to head. The two-point diff base..head gives _RUNF_PR_FILES: shared.sh
# (changed on base only) is included and base-only.sh (added on base only, a
# deletion from base to head) is not.
# Used by T-GCF-RUNF-02.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the pull_request event.
# @return 0 on success, 1 on failure
_runf_build_pr_two_point() {
  local _runf_base _runf_head

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" fork shared.sh one a.sh one >/dev/null || return 1
  gf_git "$_RUNF_REPO" checkout -q -b head || return 1
  _runf_head="$(_runf_commit_files "$_RUNF_REPO" head a.sh two b.md doc)" || return 1
  gf_git "$_RUNF_REPO" checkout -q main || return 1
  _runf_base="$(_runf_commit_files "$_RUNF_REPO" base shared.sh two base-only.sh base)" || return 1
  _runf_event_pr "$_runf_base" "$_runf_head"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# four commits on main: (1) old.sh / a.sh / c.sh created, (2) old.sh modified
# only, (3) a.sh modified, (4) c.sh modified (= HEAD). Sets the
# workflow_dispatch event and _RUNF_COMMIT_COUNT=2, so the range is
# HEAD~2..HEAD = commits (3) and (4): the files output holds a.sh and c.sh,
# and old.sh (changed in (1) and (2) only, outside the range) is not included.
# Used by T-GCF-RUNF-03.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; _RUNF_COMMIT_COUNT="2";
#       the workflow_dispatch event.
# @return 0 on success, 1 on failure
_runf_build_head_n_recent() {
  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" initial old.sh one a.sh one c.sh one >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" old old.sh two >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" a a.sh two >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" c c.sh two >/dev/null || return 1
  _runf_event_other
  _RUNF_COMMIT_COUNT="2"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# exactly two commits on main (N+1 for the default commit-count 1): (1) old.sh
# added, (2) new.sh added (= HEAD). Sets the workflow_dispatch event and keeps
# the default _RUNF_COMMIT_COUNT="1", so the range is HEAD~1..HEAD and the
# files output holds new.sh only.
# Used by T-GCF-RUNF-04, T-GCF-RUNF-10, T-GCF-RUNF-11, T-GCF-RUNF-12 and
# T-GCF-RUNF-29.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the workflow_dispatch event.
# @return 0 on success, 1 on failure
_runf_build_two_commits() {
  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" old old.sh one >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" new new.sh one >/dev/null || return 1
  _runf_event_other
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with a
# single commit holding a.sh and b.sh. Sets the workflow_dispatch event and
# keeps the default _RUNF_COMMIT_COUNT="1"; HEAD~1 does not exist, so before is
# the empty tree and the files output is every file of HEAD (_RUNF_A_SH_B_SH).
# Used by T-GCF-RUNF-05.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the workflow_dispatch event.
# @return 0 on success, 1 on failure
_runf_build_single_commit() {
  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" initial a.sh one b.sh two >/dev/null || return 1
  _runf_event_other
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# three commits on main: (1) a.sh added, (2) b.sh added, (3) a.sh modified
# (= HEAD). Sets the workflow_dispatch event and keeps _RUNF_COMMIT_COUNT; with
# a commit-count of 3 or more HEAD~N does not exist, so before is the empty
# tree and the files output is every file of HEAD (_RUNF_A_SH_B_SH). Shared by
# the commit-count boundary pair, so the two cases differ only in the count.
# Used by T-GCF-RUNF-19 (1001, rejected) and T-GCF-RUNF-28 (1000).
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the workflow_dispatch event.
# @return 0 on success, 1 on failure
_runf_build_three_commits_ab() {
  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" a a.sh one >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" b b.sh one >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" modify a.sh two >/dev/null || return 1
  _runf_event_other
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# two commits on main: (1) a.sh added, (2) an empty commit (= HEAD, the same
# tree as HEAD~1). Sets the workflow_dispatch event and keeps the default
# _RUNF_COMMIT_COUNT="1", so the range is HEAD~1..HEAD and the files output of
# the get-changed-files step is empty (the key is written).
# Used by T-GCF-RUNF-21.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the workflow_dispatch event.
# @return 0 on success, 1 on failure
_runf_build_empty_head() {
  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" initial a.sh one >/dev/null || return 1
  gf_git "$_RUNF_REPO" commit -q --allow-empty -m empty || return 1
  _runf_event_other
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# two commits on main: (1) base.txt, (2) every <path> added in the work tree
# (parent directories created, content = the path). Sets the push event from
# (1) to (2), so the files output of the get-changed-files step is the given
# paths. File names git prints unquoted only (non-ASCII is fine:
# core.quotePath=false).
# Used by T-GCF-RUNF-06, T-GCF-RUNF-07, T-GCF-RUNF-08, T-GCF-RUNF-09,
# T-GCF-RUNF-16, T-GCF-RUNF-17, T-GCF-RUNF-18, T-GCF-RUNF-20, T-GCF-RUNF-26
# and T-GCF-RUNF-27.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the push event.
# @arg $1.. paths — repository-relative paths added in commit (2)
# @return 0 on success, 1 on failure
_runf_build_push_files() {
  local _runf_before _runf_after _runf_path
  local -a _runf_pairs=()

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_before="$(_runf_commit_files "$_RUNF_REPO" base base.txt base)" || return 1
  for _runf_path in "$@"; do
    mkdir -p "${_RUNF_REPO}/$(dirname -- "$_runf_path")" || return 1
    _runf_pairs+=("$_runf_path" "$_runf_path")
  done
  _runf_after="$(_runf_commit_files "$_RUNF_REPO" add "${_runf_pairs[@]}")" || return 1
  _runf_event_push "$_runf_before" "$_runf_after"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# two commits on main: (1) base.txt in the work tree, (2) every <path>
# registered in the index directly (_runf_commit_index_files, content "doc"),
# and write the paths to ${GF_TMP_ROOT}/paths.txt (each terminated by NUL,
# outside the repository) for _runf_write_expected. Sets the push event from
# (1) to (2), so the files output of the get-changed-files step is the given
# paths in git's notation. For special file names.
# Used by T-GCF-RUNF-13 and T-GCF-RUNF-22.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the push event.
# @arg $1.. paths — repository-relative paths added in commit (2)
# @return 0 on success, 1 on failure
_runf_build_push_index_paths() {
  local _runf_before _runf_after _runf_path
  local -a _runf_pairs=()

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_before="$(_runf_commit_files "$_RUNF_REPO" base base.txt base)" || return 1
  for _runf_path in "$@"; do
    _runf_pairs+=("$_runf_path" doc)
  done
  printf '%s\0' "$@" >"${GF_TMP_ROOT}/paths.txt" || return 1
  _runf_after="$(_runf_commit_index_files "$_RUNF_REPO" add "${_runf_pairs[@]}")" || return 1
  _runf_event_push "$_runf_before" "$_runf_after"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# two commits on main: (1) base.txt in the work tree, (2) every path listed in
# ${GF_TMP_ROOT}/paths.txt registered in the index directly with one
# --index-info call (_runf_commit_index_paths_file). Sets the push event from
# (1) to (2), so the files output of the get-changed-files step is the listed
# paths. For many plain ASCII paths.
# Used by _runf_run_paths (T-GCF-RUNF-14, T-GCF-RUNF-15, T-GCF-RUNF-24,
# T-GCF-RUNF-25).
# Requires: _runf_setup has been called (BeforeEach); paths.txt exists.
# Sets: _RUNF_REPO — the fixture repository path; the push event.
# @return 0 on success, 1 on failure
_runf_build_push_paths_file() {
  local _runf_before _runf_after

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_before="$(_runf_commit_files "$_RUNF_REPO" base base.txt base)" || return 1
  _runf_after="$(_runf_commit_index_paths_file "$_RUNF_REPO" add)" || return 1
  _runf_event_push "$_runf_before" "$_runf_after"
}

##
# Builder: create the fixture repository _RUNF_REPO (gf_init_repo runf) with
# three commits on main, each adding one file: c1.sh, c2.sh, c3.sh (= HEAD).
# Sets the push event from _RUNF_ZERO_SHA (40 zeros, not a commit) to HEAD and
# keeps the default _RUNF_COMMIT_COUNT="1", so resolve-sha falls back to
# HEAD~1..HEAD and the files output holds c3.sh only.
# Used by T-GCF-RUNF-23.
# Requires: _runf_setup has been called (BeforeEach).
# Sets: _RUNF_REPO — the fixture repository path; the push event.
# @return 0 on success, 1 on failure
_runf_build_zero_before() {
  local _runf_head

  _RUNF_REPO="$(gf_init_repo runf)" || return 1
  _runf_commit_files "$_RUNF_REPO" c1 c1.sh one >/dev/null || return 1
  _runf_commit_files "$_RUNF_REPO" c2 c2.sh two >/dev/null || return 1
  _runf_head="$(_runf_commit_files "$_RUNF_REPO" c3 c3.sh three)" || return 1
  _runf_event_push "$_RUNF_ZERO_SHA" "$_runf_head"
}

# 件数を指定した一覧 (DR-15)

##
# Write ${GF_TMP_ROOT}/paths.txt (each path terminated by NUL, outside the
# repository) with <count> short ASCII paths "f0001.sh" .. (printf
# 'f%04d.sh'), 8 bytes each (9 with its LF up to 9999 paths), so that 3000 /
# 3001 paths stay far below the 120000-byte limit of the list.
# Used by _runf_run_paths (T-GCF-RUNF-14, T-GCF-RUNF-24).
# Requires: _runf_setup has been called (BeforeEach); 1 <= <count> <= 9999.
# @arg $1 count — number of paths
# @return 0 on success, non-zero on failure
_runf_write_paths_of_count() {
  local -a _runf_indexes
  mapfile -t _runf_indexes < <(seq 1 "$1") || return 1
  printf 'f%04d.sh\0' "${_runf_indexes[@]}" >"${GF_TMP_ROOT}/paths.txt"
}

# バイト数を指定した一覧 (DR-15)

##
# Write ${GF_TMP_ROOT}/paths.txt (each path terminated by NUL, outside the
# repository) with ASCII paths whose list, joined by LF with no trailing LF, is
# exactly <bytes> bytes. Each path is "dNN/f<index>", the index zero-padded so
# that the path is 100 bytes (101 with its LF), split into directories of 100
# paths; one last path "z/x..." takes the remaining 10 to 110 bytes. Every path
# component stays within 255 bytes. Counted under LC_ALL=C, so awk pads and
# measures in bytes. 120001 bytes gives 1189 paths, far below the 3000-line
# limit, so the byte limit is the one hit.
# Used by _runf_run_paths (T-GCF-RUNF-15, T-GCF-RUNF-25).
# Requires: _runf_setup has been called (BeforeEach); 10 <= <bytes> < 1010010
# (so that "dNN" keeps two digits and every padded path stays 100 bytes).
# @arg $1 bytes — byte count of the LF-joined list
# @return 0 on success, non-zero on failure (pipefail is set in a subshell,
#         so it does not leak to the caller)
_runf_write_paths_of_bytes() {
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
# Fixture self-check: compare the byte count of the list in
# ${GF_TMP_ROOT}/paths.txt, joined by LF with no trailing LF (counted under
# LC_ALL=C), with <bytes> by the test(1) operator <op>. Checked before the
# fixture is built, so that a wrong list never reaches the chain: "-le" keeps a
# count list within the byte limit (so the line limit is the one tested), "-eq"
# makes a byte list exactly <bytes> bytes.
# Used by _runf_run_paths (T-GCF-RUNF-14 and T-GCF-RUNF-24 with -le,
# T-GCF-RUNF-15 and T-GCF-RUNF-25 with -eq).
# Requires: a paths.txt writer (_runf_write_paths_of_*) has written paths.txt.
# @arg $1 op    — test(1) integer operator (-le / -eq)
# @arg $2 bytes — byte count to compare with
# @stderr the actual byte count when the comparison fails
# @return 0 when "<actual> <op> <bytes>" holds, 1 otherwise
_runf_paths_check_bytes() {
  local _list
  _list="$(tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt")" || return 1
  local LC_ALL=C
  test "${#_list}" "$1" "$2" && return 0
  echo "paths.txt list is ${#_list} bytes, expected $1 $2" >&2
  return 1
}

##
# Fixture self-check: ${GF_TMP_ROOT}/paths.txt holds exactly <count> NUL
# bytes, i.e. <count> NUL-terminated paths. Checked before the fixture is
# built, so that a count list with too few or too many paths (a seq failure
# that "|| return 1" after mapfile does not see) never reaches the chain.
# Used by _runf_run_paths (T-GCF-RUNF-14, T-GCF-RUNF-24).
# Requires: _runf_write_paths_of_count has written paths.txt.
# @arg $1 count — expected number of paths
# @stderr the actual number of paths when it is wrong
# @return 0 when it matches, 1 otherwise
_runf_paths_check_count() {
  local _count
  _count=$(tr -cd '\0' <"${GF_TMP_ROOT}/paths.txt" | wc -c) || return 1
  ((_count == $1)) && return 0
  echo "paths.txt has ${_count} paths, expected $1" >&2
  return 1
}

# 所要時間の記録 (implementation.md §1.3)
# Informational only: the timings never decide a result, and nothing is
# written to the subject's stdout or stderr. Used by _runf_run_paths
# (T-GCF-RUNF-14, T-GCF-RUNF-15, T-GCF-RUNF-24, T-GCF-RUNF-25).

##
# Store the current time in microseconds in the variable named <var>, read
# from EPOCHREALTIME with its (locale-dependent) decimal separator removed.
# @arg $1 var — name of the variable to set
# @return 0 always
_runf_now_us() {
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
# @arg $1 case  — Test ID of the case (e.g. T-GCF-RUNF-14)
# @arg $2 start — time before building the fixture (_runf_now_us)
# @arg $3 built — time after building it, before the run
# @arg $4 done  — time after the run
# @return 0 always
_runf_record_timing() {
  [ -n "${GCF_FIXTURE_TIMING:-}" ] || return 0
  local _fixture=$(($3 - $2)) _run=$(($4 - $3))

  {
    printf '%s\tfixture=%d.%06d\trun=%d.%06d\n' "$1" \
      $((_fixture / 1000000)) $((_fixture % 1000000)) \
      $((_run / 1000000)) $((_run % 1000000)) >>"$GCF_FIXTURE_TIMING"
  } 2>/dev/null || :
}

# fixture の組み立てと実行 (所要時間を記録するケース)

##
# Write paths.txt for a list of many paths, self-check it, build the fixture
# (_runf_build_push_paths_file) and run the chain. <kind> selects the list:
#   count — <n> short paths (_runf_write_paths_of_count), checked to be
#           exactly <n> paths (_runf_paths_check_count) and within 120000
#           bytes, so that only the line limit can be hit;
#   bytes — ASCII paths whose LF-joined list is exactly <n> bytes
#           (_runf_write_paths_of_bytes), checked to be exactly <n> bytes.
# paths.txt is kept, so a case can build its expected list from it afterwards
# (_runf_files_match_expected). The status of the chain is returned as is, so
# the runner serves accepted and rejected cases alike. A fixture failure (an
# unknown <kind> included) stops with _setup_failed before the chain runs. The
# fixture build time and the run time are recorded for <case> with
# _runf_record_timing (only when GCF_FIXTURE_TIMING is set).
# Used by T-GCF-RUNF-14 (count 3001), T-GCF-RUNF-15 (bytes 120001),
# T-GCF-RUNF-24 (count 3000), T-GCF-RUNF-25 (bytes 120000).
# Requires: _runf_install_copy has been called.
# @arg $1 case — Test ID of the case, for the timing record
# @arg $2 kind — count / bytes
# @arg $3 n    — number of paths (count) or byte count of the list (bytes)
# @stdout / @stderr the output of the steps, or a setup-failure message
# @return the exit code of _runf_chain, or _SETUP_FAILED (98)
_runf_run_paths() {
  local _start _built _done _status=0

  _runf_now_us _start
  case "$2" in
  count)
    _runf_write_paths_of_count "$3" || _setup_failed runf || return
    _runf_paths_check_count "$3" || _setup_failed runf || return
    _runf_paths_check_bytes -le 120000 || _setup_failed runf || return
    ;;
  bytes)
    _runf_write_paths_of_bytes "$3" || _setup_failed runf || return
    _runf_paths_check_bytes -eq "$3" || _setup_failed runf || return
    ;;
  *)
    _setup_failed runf || return
    ;;
  esac
  _runf_build_push_paths_file || _setup_failed runf || return
  _runf_now_us _built
  _runf_chain "$_RUNF_REPO" || _status=$?
  _runf_now_us _done
  _runf_record_timing "$1" "$_start" "$_built" "$_done"
  return "$_status"
}

# 期待値ファイル (implementation.md §1.3、DR-15)

##
# Turn raw paths (each terminated by NUL, so that a path may hold LF) into one
# line in the form "git -c core.quotePath=false diff --name-only" prints it: a
# path holding a character git quotes is written as a C-style quoted path
# wrapped in "...", any other path is passed through. The single place where
# the git quote notation is built (R-DIF-004, DR-06). Handled: '\' -> '\\',
# '"' -> '\"', TAB -> '\t', LF -> '\n'. The "\" substitution comes first, so
# the backslashes added by the later ones are not doubled. The "t" branch
# fires when any of them substituted in the record. The TAB is put into the
# sed script as a real TAB byte built by bash ($'\t'), because "\t" in a regex
# is not portable across sed versions; "\n" matches the LF inside a record
# under GNU sed -z.
# Used by _runf_write_expected.
# @stdin  raw paths, each terminated by NUL
# @stdout the paths in git's notation, one per line
# @return 0 on success, non-zero on failure (of tr; the caller sets pipefail
#         to catch a sed failure)
_runf_quote_paths() {
  local tab=$'\t'
  LC_ALL=C sed -z \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e "s/${tab}/\\\\t/g" \
    -e 's/\n/\\n/g' \
    -e 't quote' -e 'b' \
    -e ':quote' -e 's/.*/"&"/' |
    tr '\0' '\n'
}

##
# Build ${GF_TMP_ROOT}/expected.txt from ${GF_TMP_ROOT}/paths.txt (each path
# terminated by NUL): the paths sorted with "LC_ALL=C sort -z", the byte order
# in which "git diff --name-only" prints them (DR-15), and then written one per
# line in git's quote notation with _runf_quote_paths (git sorts the raw
# paths, so the sort comes first). The single place where paths.txt is turned
# into the expected list.
# Used by _runf_files_match_expected (T-GCF-RUNF-13, T-GCF-RUNF-14,
# T-GCF-RUNF-22, T-GCF-RUNF-24, T-GCF-RUNF-25).
# Requires: a builder or _runf_run_paths has written paths.txt.
# @return 0 on success, non-zero when sort or _runf_quote_paths fails
#         (pipefail is set in a subshell, so it does not leak to the caller)
_runf_write_expected() {
  (
    set -o pipefail
    LC_ALL=C sort -z "${GF_TMP_ROOT}/paths.txt" | _runf_quote_paths >"${GF_TMP_ROOT}/expected.txt"
  )
}

##
# Build ${GF_TMP_ROOT}/expected.txt (_runf_write_expected) and compare the
# files output of the step output file <file> (no trailing LF) with it by
# diff, appending one LF to match the line-terminated file.
# Used by T-GCF-RUNF-13, T-GCF-RUNF-14, T-GCF-RUNF-22, T-GCF-RUNF-24 and
# T-GCF-RUNF-25.
# Requires: a builder or _runf_run_paths has written paths.txt and the chain
# has run.
# @arg $1 file — step output file holding the files output
# @stderr a message when expected.txt cannot be built, or the diff when they
#         differ
# @return 0 when they match, non-zero otherwise
_runf_files_match_expected() {
  local _runf_files
  _runf_write_expected || {
    echo "expected.txt not built (from paths.txt)" >&2
    return 1
  }
  _runf_files="$(_runf_output "$1" files)" || return 1
  diff "${GF_TMP_ROOT}/expected.txt" <(printf '%s\n' "$_runf_files") >&2
}

# 行数を指定した pattern

##
# Set the pattern input _RUNF_PATTERN to <count> glob lines "p1.md" ..
# "p<count>.md" (printf -v 'p%d.md\n', the trailing LF dropped, no blank
# line), built the same way as the 100 / 101-pattern constants of the
# filter-files spec, so the line count is exactly <count>. With [last],
# the fillers stop at "p<count-1>.md" and [last] is the <count>-th line.
# The fillers are literal names, so they match none of the fixture paths.
# The result is checked with _runf_pattern_has_lines before it is used.
# Used by T-GCF-RUNF-17 (101 lines), T-GCF-RUNF-26 (99 lines + "*.sh").
# Requires: _runf_setup has been called (BeforeEach); <count> >= 1
#           (>= 2 with [last]).
# Sets: _RUNF_PATTERN — the <count> glob lines separated by LF.
# @arg $1 count — number of pattern lines
# @arg $2 last — optional glob for the last line
# @stderr a message when the self-check fails
# @return 0 on success, 1 on failure
_runf_set_pattern_lines() {
  local -a _runf_indexes
  local _runf_fillers="$1"
  [[ $# -ge 2 ]] && _runf_fillers=$((_runf_fillers - 1))
  mapfile -t _runf_indexes < <(seq 1 "$_runf_fillers") || return 1
  printf -v _RUNF_PATTERN 'p%d.md\n' "${_runf_indexes[@]}" || return 1
  if [[ $# -ge 2 ]]; then
    _RUNF_PATTERN+="$2"
  else
    _RUNF_PATTERN="${_RUNF_PATTERN%$'\n'}"
  fi
  _runf_pattern_has_lines "$@"
}

##
# Fixture self-check: _RUNF_PATTERN has exactly <count> lines (its LFs plus
# one, so a trailing LF counts as an extra line) and, with [last], its last
# line equals [last]. Catches a filler generator (seq) that wrote too few or
# too many lines, which "|| return 1" after mapfile does not see.
# Used by _runf_set_pattern_lines (T-GCF-RUNF-17, T-GCF-RUNF-26).
# @arg $1 count — expected number of lines
# @arg $2 last  — optional expected last line
# @stderr the actual line count and last line when they are wrong
# @return 0 when both hold, 1 otherwise
_runf_pattern_has_lines() {
  local _runf_lines _runf_last="${_RUNF_PATTERN##*$'\n'}"
  _runf_lines=$(printf '%s\n' "$_RUNF_PATTERN" | wc -l) || return 1
  ((_runf_lines == $1)) && [[ $# -lt 2 || $_runf_last == "$2" ]] && return 0
  echo "pattern has ${_runf_lines} lines, last '${_runf_last}', expected $1${2:+, last '$2'}" >&2
  return 1
}

# バイト数を指定した pattern

##
# Set the variable named <var> to a pattern input of exactly <bytes> bytes
# (counted under LC_ALL=C, with no trailing LF, as filter-files counts
# INPUT_PATTERNS): 99 filler glob lines "z...z.md" and the last line <last>,
# joined by LF. The filler lengths are split as evenly as possible (they differ
# by at most one byte; about 1200 bytes each for 120000 bytes), so the input is
# 100 lines, within the line limit, and only the byte limit can be hit. The
# bytes are spread over many short lines because the glob conversion of
# filter-files (_ff_glob_to_regex_var) is quadratic in the length of one line,
# so a single long line would make an accepted case very slow. No filler line
# matches a path without the ".md" suffix (e.g. a.sh). The result is checked
# with _runf_pattern_has_bytes before it is used.
# Used by T-GCF-RUNF-18 (120001 bytes, last "*.md"), T-GCF-RUNF-27
# (120000 bytes, last "*.sh").
# Requires: <bytes> - 99 - length of <last> >= 99 * 4 (every filler line keeps
# at least one "z").
# Sets: <var> — the pattern lines separated by LF, with no trailing LF.
# @arg $1 var   — name of the variable to set (e.g. _RUNF_PATTERN)
# @arg $2 bytes — byte count of the whole input
# @arg $3 last  — the last pattern line (ASCII)
# @stderr a message when the self-check fails
# @return 0 on success, 1 on failure
_runf_patterns_of_bytes() {
  local LC_ALL=C
  local _runf_fill=$(($2 - 99 - ${#3})) _runf_z _runf_text='' _runf_i

  ((_runf_fill >= 99 * 4)) || return 1
  # the longer filler: (_runf_fill / 99 + 1) bytes = z * (that - 3) + ".md"
  printf -v _runf_z '%*s' $((_runf_fill / 99 - 2)) ''
  _runf_z="${_runf_z// /z}"
  for ((_runf_i = 0; _runf_i < 99; _runf_i++)); do
    if ((_runf_i < _runf_fill % 99)); then
      _runf_text+="${_runf_z}.md"$'\n'
    else
      _runf_text+="${_runf_z:1}.md"$'\n'
    fi
  done
  printf -v "$1" '%s' "${_runf_text}$3" || return 1
  _runf_pattern_has_bytes "$1" "$2"
}

##
# Fixture self-check: the variable named <var> holds exactly <bytes> bytes
# and at most 100 lines (at most 99 LFs, no trailing LF), so a pattern case
# hits the byte limit and never the line limit. The bytes are counted as
# check_byte_limit of filter-files counts INPUT_PATTERNS: ${#...} of the value
# as is, under a local LC_ALL=C set in its own local statement (so that ${#...}
# counts bytes, not characters).
# Used by _runf_patterns_of_bytes (T-GCF-RUNF-18, T-GCF-RUNF-27).
# @arg $1 var   — name of the variable holding the pattern input
# @arg $2 bytes — expected byte count
# @stderr the actual byte and LF counts when they are wrong
# @return 0 when both hold, 1 otherwise
_runf_pattern_has_bytes() {
  local LC_ALL=C
  local _runf_text="${!1}"
  local _runf_bytes=${#_runf_text} _runf_lfs
  _runf_lfs=$(printf '%s' "${!1}" | tr -cd '\n' | wc -c) || return 1
  ((_runf_bytes == $2 && _runf_lfs <= 99)) && return 0
  echo "pattern is ${_runf_bytes} bytes with ${_runf_lfs} LFs, expected $2 bytes and at most 99 LFs" >&2
  return 1
}

# 期待値 (It の中で git から求める)

##
# Compute the expected files output of a HEAD~1..HEAD range from git itself:
# `git diff --name-only --diff-filter=ACMR HEAD~1 HEAD` in _RUNF_REPO (AC-004).
# Called inside the It after the builder; an empty result is a fixture failure.
# Used by T-GCF-RUNF-04, T-GCF-RUNF-23 and T-GCF-RUNF-29.
# Requires: a builder has set _RUNF_REPO with at least two commits.
# Sets: _RUNF_EXPECTED — the file names separated by LF, with no trailing LF.
# @return 0 on success, 1 when git fails or the result is empty
_runf_head1_diff() {
  _RUNF_EXPECTED="$(gf_git "$_RUNF_REPO" diff --name-only --diff-filter=ACMR HEAD~1 HEAD)" || return 1
  [ -n "$_RUNF_EXPECTED" ]
}

# エラー出力と失敗時の出力の確認 (tasks.md T-04 の異常系の 4 つの確認)

##
# Satisfy-matcher for "The entire stderr should satisfy
# _runf_stderr_has_error <target>": the subject (ShellSpec stores it in the
# variable named after the matcher) has a line starting with
# "::error::<target>:", or "::error::<target>: <message>" when <message> is
# given. Internal Action errors are checked by this prefix and the target only
# (tasks.md Conventions); the errors of get-changed-files itself, the module
# under test, are checked with their wording (<message>).
# Used by T-GCF-RUNF-10, T-GCF-RUNF-11, T-GCF-RUNF-12, T-GCF-RUNF-13,
# T-GCF-RUNF-14, T-GCF-RUNF-15, T-GCF-RUNF-16, T-GCF-RUNF-17,
# T-GCF-RUNF-18, T-GCF-RUNF-19, T-GCF-RUNF-21 and T-GCF-RUNF-22.
# @arg $1 target  — error target (commit-count / files / patterns)
# @arg $2 message — optional wording expected after "<target>: "
# @stderr the actual stderr when no line matches
# @return 0 when a line matches, 1 otherwise
_runf_stderr_has_error() {
  local _runf_line _runf_prefix="::error::$1:"

  [ -n "${2:-}" ] && _runf_prefix+=" $2"
  while IFS= read -r _runf_line; do
    [[ $_runf_line == "$_runf_prefix"* ]] && return 0
  done <<<"$_runf_stderr_has_error"
  printf 'no "%s" line in stderr: %q\n' "$_runf_prefix" "$_runf_stderr_has_error" >&2
  return 1
}

##
# Succeed when the Action publishes neither files nor count: the output file of
# the filter-files step does not exist, or it has neither key (tasks.md T-04,
# error-case check (d)). Used with "The result of function
# _runf_no_public_outputs should be successful" (the result subject is set
# only when the function returns 0).
# Used by T-GCF-RUNF-10, T-GCF-RUNF-11, T-GCF-RUNF-12, T-GCF-RUNF-13,
# T-GCF-RUNF-14, T-GCF-RUNF-15, T-GCF-RUNF-16, T-GCF-RUNF-17,
# T-GCF-RUNF-18, T-GCF-RUNF-19, T-GCF-RUNF-21 and T-GCF-RUNF-22.
# @stdout nothing
# @return 0 when neither output is published, 1 otherwise
_runf_no_public_outputs() {
  [ -f "$_RUNF_OUT_FF" ] || return 0
  ! _runf_has_key "$_RUNF_OUT_FF" files && ! _runf_has_key "$_RUNF_OUT_FF" count
}

# --- テスト本体 ---

##
# ca-get-changed-files: resolve the before / after commits of the event
# (resolve-sha), list the files changed between them (get-changed-files) and
# filter them by the pattern (filter-files); the files / count outputs of the
# Action are those of the filter-files step.
Describe 'ca-get-changed-files'
  BeforeEach '_runf_setup'
  AfterEach 'gf_cleanup'

  ##
  # action.yml の step 連鎖: the three scripts run in the step order of
  # action.yml from a copy outside the repository, each step with its own
  # output file and the outputs of the previous step as its env.
  # Scenarios:
  #   normal (exit 0 with an empty stderr): a push event returns the files
  #     changed between before and after with their count; a pull_request
  #     event returns the files of the two-point diff between base and head;
  #     another event returns the files changed in HEAD~N..HEAD only; a
  #     multiline pattern with an exclusion narrows the files and the count;
  #     an empty pattern returns every file; a pattern matching no file
  #     returns an empty files output (the key is written) and count 0; the
  #     chain also runs when the working directory has no .github/actions
  #     (the internal Actions are found from GITHUB_ACTION_PATH).
  #   error (non-zero exit with an "::error::<target>:" line): an invalid
  #     commit-count stops the chain at resolve-sha; a list over the byte
  #     limit stops it at get-changed-files; a git-quoted path, a list over
  #     the line limit and an invalid or oversized pattern stop it at
  #     filter-files. The failed step writes no output, the later steps are
  #     never run and the Action publishes neither files nor count.
  Describe 'action.yml の step 連鎖'
    # Cases where the chain succeeds and the filter-files step writes files / count
    Context 'When: 正常系'
      It '[Normal] T-GCF-RUNF-01: push で before..after の変更ファイルを返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_modify_add || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_A_SH_B_MD"
        The result of function _runf_ff_count should equal 2
      End

      It '[Normal] T-GCF-RUNF-02: pull_request で base..head の変更ファイルを返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_pr_two_point || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_PR_FILES"
      End

      It '[Normal] T-GCF-RUNF-03: その他イベントで HEAD~N..HEAD の変更ファイルを返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_head_n_recent || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should include 'a.sh'
        The result of function _runf_ff_files should include 'c.sh'
        The result of function _runf_ff_files should not include 'old.sh'
      End

      It '[Normal] T-GCF-RUNF-04: commit-count が既定値なら HEAD~1..HEAD を返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_two_commits || _setup_failed runf
        _runf_head1_diff || _setup_failed expected
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_EXPECTED"
      End

      It '[Normal] T-GCF-RUNF-05: 履歴が 1 コミットなら HEAD の全ファイルを返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_single_commit || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_A_SH_B_SH"
      End

      It '[Normal] T-GCF-RUNF-06: 複数行の pattern と除外で絞り込む'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files src/a.sh src/gen/b.sh README.md || _setup_failed runf
        _RUNF_PATTERN="$_RUNF_PATTERN_SRC_EXCL_GEN"
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal 'src/a.sh'
        The result of function _runf_ff_count should equal 1
      End

      It '[Normal] T-GCF-RUNF-07: pattern が空なら全件を返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh dir/b.md || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_A_SH_DIR_B_MD"
        The result of function _runf_ff_count should equal 2
      End

      It '[Normal] T-GCF-RUNF-08: 一致 0 件は空の files と count "0" で成功する'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        _RUNF_PATTERN='*.yml'
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        Assert _runf_has_key "$_RUNF_OUT_FF" files
        The result of function _runf_ff_files should equal ''
        The result of function _runf_ff_count should equal 0
      End

      It '[Normal] T-GCF-RUNF-09: 作業ディレクトリに内部 Action が無くても動く'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The path "${_RUNF_REPO}/.github/actions" should not be exist
        Assert _runf_has_key "$_RUNF_OUT_RS" before_sha
        Assert _runf_has_key "$_RUNF_OUT_RS" after_sha
        Assert _runf_has_key "$_RUNF_OUT_GCF" files
        Assert _runf_has_key "$_RUNF_OUT_FF" files
        Assert _runf_has_key "$_RUNF_OUT_FF" count
      End
    End

    # Cases where a step fails: the chain stops there and publishes no output
    Context 'When: 異常系'
      # commit-count 0 is rejected by resolve-sha, the first step, so neither
      # later step runs (AC-005)
      It '[Error] T-GCF-RUNF-10: commit-count が 0'
        _runf_install_copy || _setup_failed copy
        _runf_build_two_commits || _setup_failed runf
        _RUNF_COMMIT_COUNT="0"
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error commit-count
        The contents of file "$_RUNF_OUT_RS" should equal ''
        The path "$_RUNF_OUT_GCF" should not be exist
        The path "$_RUNF_OUT_FF" should not be exist
        The result of function _runf_no_public_outputs should be successful
      End

      # a negative commit-count is rejected by resolve-sha, the first step
      # (AC-005)
      It '[Error] T-GCF-RUNF-11: commit-count が -1'
        _runf_install_copy || _setup_failed copy
        _runf_build_two_commits || _setup_failed runf
        _RUNF_COMMIT_COUNT="-1"
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error commit-count
        The contents of file "$_RUNF_OUT_RS" should equal ''
        The path "$_RUNF_OUT_GCF" should not be exist
        The path "$_RUNF_OUT_FF" should not be exist
        The result of function _runf_no_public_outputs should be successful
      End

      # a non-numeric commit-count is rejected by resolve-sha, the first step
      # (AC-005)
      It '[Error] T-GCF-RUNF-12: commit-count が abc'
        _runf_install_copy || _setup_failed copy
        _runf_build_two_commits || _setup_failed runf
        _RUNF_COMMIT_COUNT="abc"
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error commit-count
        The contents of file "$_RUNF_OUT_RS" should equal ''
        The path "$_RUNF_OUT_GCF" should not be exist
        The path "$_RUNF_OUT_FF" should not be exist
        The result of function _runf_no_public_outputs should be successful
      End

      # get-changed-files passes the git-quoted path on as is; filter-files,
      # the last step, rejects it (AC-011)
      It '[Error] T-GCF-RUNF-13: ダブルクオートを含むパスがある差分'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_index_paths 'a"b.sh' || _setup_failed runf
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error files
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
        Assert _runf_files_match_expected "$_RUNF_OUT_GCF"
      End

      # 3001 paths within the byte limit pass get-changed-files; filter-files
      # rejects them by the line limit (AC-012, DR-07)
      It '[Error] T-GCF-RUNF-14: 3001 件の差分'
        _runf_install_copy || _setup_failed copy
        When call _runf_run_paths T-GCF-RUNF-14 count 3001
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error files
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
        Assert _runf_files_match_expected "$_RUNF_OUT_GCF"
      End

      # get-changed-files rejects a list over its own byte limit with its own
      # wording, matched from the start of the line, so the filter-files step
      # never runs (AC-012, DR-13)
      It '[Error] T-GCF-RUNF-15: 120001 バイトの差分'
        _runf_install_copy || _setup_failed copy
        When call _runf_run_paths T-GCF-RUNF-15 bytes 120001
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error files 'exceeds the limit of 120000 bytes'
        The contents of file "$_RUNF_OUT_GCF" should equal ''
        The path "$_RUNF_OUT_FF" should not be exist
        The result of function _runf_no_public_outputs should be successful
      End

      # an exclude pattern with nothing after "!" is rejected by filter-files,
      # the last step (AC-018)
      It '[Error] T-GCF-RUNF-16: pattern が "!" だけの 1 行'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        _RUNF_PATTERN='!'
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error patterns
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
      End

      # a pattern over the line limit is rejected by filter-files, the last
      # step (AC-018)
      It '[Error] T-GCF-RUNF-17: pattern が 101 行'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        _runf_set_pattern_lines 101 || _setup_failed pattern
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error patterns
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
      End

      # a pattern over the byte limit (100 lines, none matching a.sh) is
      # rejected by filter-files, the last step (REQ-F-006, _ca-filter-files
      # REQ-F-018)
      It '[Error] T-GCF-RUNF-18: pattern が 120001 バイト'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        _runf_patterns_of_bytes _RUNF_PATTERN 120001 '*.md' || _setup_failed pattern
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error patterns
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
      End

      # a commit-count one over the limit of 1000 is rejected by resolve-sha,
      # the first step (AC-005, _ca-resolve-sha REQ-F-002)
      It '[Error] T-GCF-RUNF-19: commit-count が上限を 1 超える 1001'
        _runf_install_copy || _setup_failed copy
        _runf_build_three_commits_ab || _setup_failed runf
        _RUNF_COMMIT_COUNT="1001"
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error commit-count
        The contents of file "$_RUNF_OUT_RS" should equal ''
        The path "$_RUNF_OUT_GCF" should not be exist
        The path "$_RUNF_OUT_FF" should not be exist
        The result of function _runf_no_public_outputs should be successful
      End
    End

    # Edge cases: unusual paths, boundary sizes and histories
    Context 'When: エッジケース'
      # git prints the non-ASCII path as is (core.quotePath=false), so the
      # pattern matches it (AC-010, DR-06)
      It '[Edge] T-GCF-RUNF-20: 非 ASCII のパスを pattern で絞り込める'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files 'docs/日本語.md' a.sh || _setup_failed runf
        _RUNF_PATTERN='docs/**'
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal 'docs/日本語.md'
        The result of function _runf_ff_count should equal 1
      End

      # an empty HEAD commit gives an empty list, yet filter-files still
      # rejects the invalid pattern (spec index §5, AC-018)
      It '[Edge] T-GCF-RUNF-21: 変更が無くても不正な pattern はエラーにする'
        _runf_install_copy || _setup_failed copy
        _runf_build_empty_head || _setup_failed runf
        _RUNF_PATTERN='!'
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error patterns
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
        Assert _runf_has_key "$_RUNF_OUT_GCF" files
        The result of function _runf_gcf_files should equal ''
      End

      # filter-files rejects the git-quoted path before filtering, even though
      # the pattern would exclude it (spec index §5, DR-07)
      It '[Edge] T-GCF-RUNF-22: 除外されるパスに引用表記があってもエラーにする'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_index_paths a.sh 'a"b.md' || _setup_failed runf
        _RUNF_PATTERN='*.sh'
        When call _runf_chain "$_RUNF_REPO"
        The status should not equal 0
        The entire stderr should satisfy _runf_stderr_has_error files
        The contents of file "$_RUNF_OUT_FF" should equal ''
        The result of function _runf_no_public_outputs should be successful
        Assert _runf_files_match_expected "$_RUNF_OUT_GCF"
      End

      # an all-zero before (a new branch) is not a commit, so resolve-sha
      # falls back to HEAD~1..HEAD (REQ-C-008 migration item 4, REQ-F-002)
      It '[Edge] T-GCF-RUNF-23: push の before が全ゼロなら HEAD~1..HEAD を返す'
        _runf_install_copy || _setup_failed copy
        _runf_build_zero_before || _setup_failed runf
        _runf_head1_diff || _setup_failed expected
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_EXPECTED"
      End

      # exactly 3000 paths within the byte limit pass both limits, so the
      # whole list comes out (AC-012, DR-07; the "=" side of T-GCF-RUNF-14)
      It '[Edge] T-GCF-RUNF-24: 3000 件ちょうどの差分は受け付ける'
        _runf_install_copy || _setup_failed copy
        When call _runf_run_paths T-GCF-RUNF-24 count 3000
        The status should equal 0
        The stderr should equal ''
        Assert _runf_files_match_expected "$_RUNF_OUT_FF"
        The result of function _runf_ff_count should equal 3000
      End

      # a list of exactly 120000 bytes (1189 lines) passes the byte limit of
      # get-changed-files and that of filter-files, so both stages share the
      # same limit (AC-012, R-DIF-033, DR-13; the "=" side of T-GCF-RUNF-15)
      It '[Edge] T-GCF-RUNF-25: 120000 バイトちょうどの差分は両方の段で受け付ける'
        _runf_install_copy || _setup_failed copy
        When call _runf_run_paths T-GCF-RUNF-25 bytes 120000
        The status should equal 0
        The stderr should equal ''
        Assert _runf_files_match_expected "$_RUNF_OUT_FF"
      End

      # a pattern of exactly 100 lines (99 non-matching globs and "*.sh")
      # passes the line limit and filters the list (AC-018; the "=" side of
      # T-GCF-RUNF-17)
      It '[Edge] T-GCF-RUNF-26: pattern が 100 行ちょうどなら受け付ける'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh b.md || _setup_failed runf
        _runf_set_pattern_lines 100 '*.sh' || _setup_failed pattern
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal 'a.sh'
        The result of function _runf_ff_count should equal 1
      End

      # a pattern of exactly 120000 bytes (99 non-matching globs and "*.sh",
      # 100 lines) passes the byte limit (REQ-F-006; the "=" side of
      # T-GCF-RUNF-18)
      It '[Edge] T-GCF-RUNF-27: pattern が 120000 バイトちょうどなら受け付ける'
        _runf_install_copy || _setup_failed copy
        _runf_build_push_files a.sh || _setup_failed runf
        _runf_patterns_of_bytes _RUNF_PATTERN 120000 '*.sh' || _setup_failed pattern
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal 'a.sh'
        The result of function _runf_ff_count should equal 1
      End

      # commit-count 1000 (the upper limit) is accepted; the 3-commit history
      # is shorter than N+1, so before is the empty tree and the files output
      # is every file of HEAD (REQ-F-002; the "=" side of T-GCF-RUNF-19)
      It '[Edge] T-GCF-RUNF-28: commit-count が上限の 1000 なら受け付ける'
        _runf_install_copy || _setup_failed copy
        _runf_build_three_commits_ab || _setup_failed runf
        _RUNF_COMMIT_COUNT="1000"
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_A_SH_B_SH"
      End

      # an explicit empty commit-count (set but empty, not unset) means the
      # default 1, so the range is HEAD~1..HEAD (_ca-resolve-sha DD-IN-02)
      It '[Edge] T-GCF-RUNF-29: commit-count が空文字列なら既定値 1 として扱う'
        _runf_install_copy || _setup_failed copy
        _runf_build_two_commits || _setup_failed runf
        _runf_head1_diff || _setup_failed expected
        _RUNF_COMMIT_COUNT=''
        When call _runf_chain "$_RUNF_REPO"
        The status should equal 0
        The stderr should equal ''
        The result of function _runf_ff_files should equal "$_RUNF_EXPECTED"
      End
    End
  End
End
