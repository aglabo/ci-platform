#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/_libs/__tests__/unit/get-changed-files.unit.spec.sh
# @(#) : unit tests for get-changed-files.lib.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for get-changed-files.lib.sh
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh"

# --- ヘルパー ---
# Real git repository fixtures (gf_setup / gf_cleanup / gf_init_repo / gf_git / gf_run_in)
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"

# --- 内部ヘルパー ---
# 定数
# Exit code of the fixture runners (_lcf_run_*) when the fixture setup fails
# (_setup_failed); no T-GCF-LCF case expects it
_SETUP_FAILED=98
# SHA of git's empty tree, known to git without being in the object store;
# used by T-GCF-LCF-05
_EMPTY_TREE_SHA=4b825dc642cb6eb9a060e54bf8d69288fbee4904
# 40-hex SHA that no fixture repository contains; used by T-GCF-LCF-10
_MISSING_SHA=1111111111111111111111111111111111111111

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

# コミットの作成

##
# Commit what is staged in the index of <repo> and print the new commit OID.
# The single place where the fixtures create a commit.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_lcf_commit_staged() {
  gf_git "$1" commit -q -m "$2" || return 1
  gf_git "$1" rev-parse HEAD
}

##
# Write each <path> in the work tree of <repo> with <content> (followed by LF),
# stage it, commit, and print the new commit OID. Used for ordinary file names
# only (special names go through _lcf_commit_index_files).
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_lcf_commit_files() {
  local _repo="$1" _message="$2"
  shift 2

  while (($# >= 2)); do
    printf '%s\n' "$2" >"${_repo}/$1" || return 1
    gf_git "$_repo" add -- "$1" || return 1
    shift 2
  done
  _lcf_commit_staged "$_repo" "$_message"
}

##
# Register each <path> in the index of <repo> directly, with <mode> and a blob
# whose content is <content> followed by LF, commit, and print the new commit
# OID. Nothing passes through the work tree of the host file system, so special
# file names and symbolic links (120000) need no support from it.
# Requires: <repo> was created by gf_init_repo.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @arg $3 mode    — index mode of every entry (100644, 120000, ...)
# @arg $4.. pairs — <path> <content> pairs
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_lcf_commit_index_entries() {
  local _repo="$1" _message="$2" _mode="$3" _blob
  shift 3

  while (($# >= 2)); do
    _blob="$(printf '%s\n' "$2" | gf_git "$_repo" hash-object -w --stdin)" || return 1
    gf_git "$_repo" update-index --add --cacheinfo "${_mode},${_blob},$1" || return 1
    shift 2
  done
  _lcf_commit_staged "$_repo" "$_message"
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
_lcf_commit_index_files() {
  _lcf_commit_index_entries "$1" "$2" 100644 "${@:3}"
}

##
# Register every path listed in ${GF_TMP_ROOT}/paths.txt (each path terminated
# by NUL) in the index of <repo> directly, as regular files (100644) sharing
# one blob whose content is "doc" followed by LF, with a single
# "git update-index --index-info" call, commit, and print the new commit OID.
# Used for the fixtures with many paths, where one --cacheinfo call per path
# would be too slow. The paths must hold no LF, TAB or other character that
# --index-info would misread.
# Requires: <repo> was created by gf_init_repo and paths.txt exists.
# @arg $1 repo    — repository path
# @arg $2 message — commit message
# @stdout the new commit OID
# @return 0 on success, 1 on failure
_lcf_commit_index_paths_file() {
  local _repo="$1" _message="$2" _blob

  _blob="$(printf 'doc\n' | gf_git "$_repo" hash-object -w --stdin)" || return 1
  tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt" |
    awk -v blob="$_blob" '{ printf "100644 %s\t%s\n", blob, $0 }' |
    gf_git "$_repo" update-index --add --index-info || return 1
  _lcf_commit_staged "$_repo" "$_message"
}

# バイト数を指定した一覧 (DR-15)

##
# Write ${GF_TMP_ROOT}/paths.txt (each path terminated by NUL) with paths whose list,
# joined by LF with no trailing LF, is exactly <bytes> bytes. Each path is
# "dNN/<mark><index>", the index zero-padded so that the path is 100 bytes
# (101 with its LF), split into directories of 100 paths; one last ASCII path
# "z/x..." takes the remaining 10 to 110 bytes. Every path component stays
# within 255 bytes. <mark> defaults to "f" (ASCII paths); a multibyte <mark>
# such as "日" makes each 100-byte path fewer than 100 characters.
# Counted under LC_ALL=C, so awk pads and measures in bytes.
# Requires: gf_setup has been called (BeforeEach); 10 <= <bytes> < 1010010
# (so that "dNN" keeps two digits and every padded path stays 100 bytes);
# <mark> has no "\" (awk -v would read it as an escape) and leaves room for
# the index digits.
# @arg $1 bytes — byte count of the LF-joined list
# @arg $2 mark  — leading text of each padded file name (default: f)
# @return 0 on success, non-zero on failure (pipefail is set in a subshell,
#         so it does not leak to the caller)
_lcf_write_paths_of_bytes() {
  local LC_ALL=C
  local _count=$((($1 - 10) / 101)) _mark="${2:-f}" _rest

  _rest=$(($1 - _count * 101))
  (
    set -o pipefail
    awk -v count="$_count" -v rest="$_rest" -v mark="$_mark" 'BEGIN {
      fmt = "d%02d/" mark "%0" (96 - length(mark)) "d\n"
      for (i = 0; i < count; i++) printf fmt, int(i / 100), i
      last = "z/"
      while (length(last) < rest) last = last "x"
      print last
    }' | tr '\n' '\0' >"${GF_TMP_ROOT}/paths.txt"
  )
}

##
# Fixture self-check: the list in ${GF_TMP_ROOT}/paths.txt, joined by LF with
# no trailing LF, is exactly <bytes> bytes (counted under LC_ALL=C).
# @arg $1 bytes — expected byte count
# @stderr the actual byte count when it differs
# @return 0 when it matches, 1 otherwise
_lcf_paths_have_bytes() {
  local _list
  _list="$(tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt")" || return 1
  local LC_ALL=C
  [ "${#_list}" -eq "$1" ] && return 0
  echo "paths.txt list is ${#_list} bytes, expected $1" >&2
  return 1
}

##
# Fixture self-check: the list in ${GF_TMP_ROOT}/paths.txt, joined by LF with
# no trailing LF, has fewer than <chars> characters when counted under
# LC_ALL=C.UTF-8. Also fails when C.UTF-8 is not available, since the count
# then falls back to bytes.
# @arg $1 chars — exclusive upper bound of the character count
# @stderr the actual character count when it is not below <chars>
# @return 0 when it is below, 1 otherwise
_lcf_paths_have_fewer_chars() {
  local _list
  _list="$(tr '\0' '\n' <"${GF_TMP_ROOT}/paths.txt")" || return 1
  local LC_ALL=C.UTF-8
  [ "${#_list}" -lt "$1" ] && return 0
  echo "paths.txt list is ${#_list} characters under C.UTF-8, expected fewer than $1" >&2
  return 1
}

# 期待値ファイル (DR-15)

##
# Filter that turns each NUL-terminated record of stdin (one raw path, which
# may hold LF) into one line in the form
# "git -c core.quotePath=false diff --name-only" prints it: a path holding a
# character git quotes is written as a C-style quoted path wrapped in "...",
# any other path is passed through. The single place where the git quote
# notation is built (R-DIF-004, DR-06). Handled: '\' -> '\\', '"' -> '\"',
# TAB -> '\t', LF -> '\n'. Each further character is one more "s" command
# before "t quote". The "\" substitution comes first, so the backslashes added
# by the later ones are not doubled. The "t" branch fires when any of them
# substituted in the record. The TAB is put into the sed script as a real TAB
# byte built by bash ($'\t'), because "\t" in a regex is not portable across
# sed versions; "\n" matches the LF inside a record under GNU sed -z. The
# records are read with -z, so a path with LF stays one record, and turned
# into lines at the end (no LF is left in them by then).
# @stdin  raw paths, each terminated by NUL
# @stdout the paths in git's notation, one per line
# @return 0 on success, non-zero on failure (of tr; the caller sets pipefail
#         to catch a sed failure)
_lcf_quote_paths() {
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
# terminated by NUL, so that a path may hold LF): the paths sorted with
# "LC_ALL=C sort -z", the byte order in which "git diff --name-only" prints
# them (DR-15), and then written one per line in git's quote notation with
# _lcf_quote_paths (git sorts the raw paths, so the sort comes first). This is
# the single place where paths.txt is turned into the expected list.
# Requires: gf_setup has been called (BeforeEach) and paths.txt exists.
# @return 0 on success, non-zero when sort or _lcf_quote_paths fails
#         (pipefail is set in a subshell, so it does not leak to the caller)
_lcf_write_expected() {
  (
    set -o pipefail
    LC_ALL=C sort -z "${GF_TMP_ROOT}/paths.txt" | _lcf_quote_paths >"${GF_TMP_ROOT}/expected.txt"
  )
}

##
# Satisfy-matcher for "The entire stdout should satisfy _lcf_matches_expected":
# compare the subject (ShellSpec stores it in the variable named after this
# function) with ${GF_TMP_ROOT}/expected.txt by diff. The subject has no
# trailing LF, so one LF is appended to match the line-terminated file.
# @stderr the diff when they differ
# @return 0 when they match, 1 otherwise
_lcf_matches_expected() {
  diff "${GF_TMP_ROOT}/expected.txt" <(printf '%s\n' "${_lcf_matches_expected}") >&2
}

# 所要時間の記録 (implementation.md §1.3)
# Informational only: the timings never decide a result, and nothing is
# written to the subject's stdout or stderr.

##
# Store the current time in microseconds in the variable named <var>, read
# from EPOCHREALTIME with its (locale-dependent) decimal separator removed.
# @arg $1 var — name of the variable to set
# @return 0 always
_lcf_now_us() {
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
# @arg $1 case    — Test ID of the case (e.g. T-GCF-LCF-13)
# @arg $2 start   — time before building the fixture (_lcf_now_us)
# @arg $3 built   — time after building it, before the run
# @arg $4 done    — time after the run
# @return 0 always
_lcf_record_timing() {
  [ -n "${GCF_FIXTURE_TIMING:-}" ] || return 0
  local _fixture=$(($3 - $2)) _run=$(($4 - $3))

  {
    printf '%s\tfixture=%d.%06d\trun=%d.%06d\n' "$1" \
      $((_fixture / 1000000)) $((_fixture % 1000000)) \
      $((_run / 1000000)) $((_run % 1000000)) >>"$GCF_FIXTURE_TIMING"
  } 2>/dev/null || :
}

# エラー出力の確認
# The matchers below receive "The entire stderr" as their subject (ShellSpec
# stores it in the variable named after the matcher), so it keeps the trailing
# LF of the error line. They split it with _lcf_split_last_line.

##
# Split <text> into its last line and the lines before it, ignoring one
# trailing LF: sets _lcf_last to the last line (CR kept) and _lcf_head to the
# text before it, which is empty when <text> has a single line. The single
# place where the error matchers take the last stderr line.
# @arg $1 text — the matcher's subject
# @return 0 always
_lcf_split_last_line() {
  local _text="${1%$'\n'}"

  _lcf_last="${_text##*$'\n'}"
  _lcf_head="${_text%"$_lcf_last"}"
}

##
# Satisfy-matcher for "The entire stderr should satisfy
# _lcf_ends_with_list_error <value>": the last line of the subject equals the
# R-DIF-002 error whose value is <value>..<after>, with the after OID read
# from ${GF_TMP_ROOT}/after.txt (written by _lcf_run_bad_before). <value> is
# the before side as it should appear in the line (already encoded).
# @arg $1 value — expected before side of the error value
# @stderr the expected and the actual last line when they differ, or a
#         message when after.txt cannot be read
# @return 0 when it matches, 1 otherwise
_lcf_ends_with_list_error() {
  local _lcf_last _lcf_head _after _expected

  _after="$(<"${GF_TMP_ROOT}/after.txt")" || {
    echo "after.txt not readable (written by _lcf_run_bad_before)" >&2
    return 1
  }
  _expected="::error::files: failed to list changed files (got: '${1}..${_after}')"
  _lcf_split_last_line "$_lcf_ends_with_list_error"
  [ "$_lcf_last" = "$_expected" ] && return 0
  printf 'expected last line: %q\nactual last line:   %q\n' "$_expected" "$_lcf_last" >&2
  return 1
}

##
# Satisfy-matcher for "The entire stderr should satisfy
# _lcf_last_line_has_no_cr": the last line of the subject contains no CR
# (DD-IDX-01). Only the last line is checked, since git's own output before
# it may echo the raw value.
# @stderr the actual last line when it contains a CR
# @return 0 when it has no CR, 1 otherwise
_lcf_last_line_has_no_cr() {
  local _lcf_last _lcf_head

  _lcf_split_last_line "$_lcf_last_line_has_no_cr"
  [[ $_lcf_last != *$'\r'* ]] && return 0
  printf 'last line has a CR: %q\n' "$_lcf_last" >&2
  return 1
}

##
# Satisfy-matcher for "The entire stderr should satisfy
# _lcf_has_git_output_before_last": the lines before the last line of the
# subject are byte for byte the stderr of the same git diff run directly in
# the same repository, read from ${GF_TMP_ROOT}/git-stderr.txt (written by
# _lcf_run_bad_before), and that stderr is not empty (git's own output passes
# through unchanged, DR-14).
# @stderr the expected and the actual lines before the last line when they
#         differ, or a message when git-stderr.txt cannot be read or is empty
# @return 0 when they match, 1 otherwise
_lcf_has_git_output_before_last() {
  local _lcf_last _lcf_head _file="${GF_TMP_ROOT}/git-stderr.txt" _expected=''

  [ -r "$_file" ] || {
    echo "git-stderr.txt not readable (written by _lcf_run_bad_before)" >&2
    return 1
  }
  # read -d '' keeps every byte, trailing LFs included; it returns 1 at EOF
  IFS= read -r -d '' _expected <"$_file" || :
  [ -n "$_expected" ] || {
    echo "git diff printed nothing on stderr (git-stderr.txt is empty)" >&2
    return 1
  }
  _lcf_split_last_line "$_lcf_has_git_output_before_last"
  [ "$_lcf_head" = "$_expected" ] && return 0
  printf 'expected lines before the last: %q\nactual lines before the last:   %q\n' \
    "$_expected" "$_lcf_head" >&2
  return 1
}

# fixture の作成と list_changed_files の実行
# Every _lcf_run_* below builds its repository inside the It and runs
# list_changed_files <before> <after> in it with gf_run_in. A fixture failure
# returns _SETUP_FAILED instead of running list_changed_files.
# Requires: gf_setup has been called (BeforeEach).
# @stdout list_changed_files's stdout
# @stderr list_changed_files's stderr, or a setup-failure message
# @return list_changed_files's exit code, or _SETUP_FAILED (98)

##
# before: a.sh / after: a.sh modified and b.md added; then run <command>
# <before> <after> in the repository with gf_run_in. The single place where
# this fixture is built. Shared by _lcf_run_modify_add and
# _lcf_run_source_twice.
# @arg $@ command — command and its leading arguments; <before> and <after>
#                   are appended as its last two arguments
_lcf_run_with_modify_add() {
  local _repo _before _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before a.sh one)" || _setup_failed lcf || return
  _after="$(_lcf_commit_files "$_repo" after a.sh two b.md doc)" || _setup_failed lcf || return
  gf_run_in "$_repo" "$@" "$_before" "$_after"
}

##
# before: a.sh / after: a.sh modified and b.md added. Used by T-GCF-LCF-01.
_lcf_run_modify_add() {
  _lcf_run_with_modify_add list_changed_files
}

##
# Same repository as _lcf_run_modify_add, but list_changed_files runs in a
# fresh bash that sources get-changed-files.lib.sh twice. A fresh process is
# needed because the readonly constants from the spec's own Include are
# inherited by any subshell, so a re-source there fails even the first time.
# The guard variable is unset first, so that a value exported from the
# environment cannot make the first source a no-op.
# The inner bash gets the library path, <before> and <after> as $1, $2 and
# $3, always quoted, so a path with spaces is passed as one argument.
# A first source that returns non-zero, or a second one that does, is
# reported on stderr and makes the run exit 1. The library's own error
# output goes to stderr as is: a readonly redefinition does not make the
# source return non-zero, so it is caught by the empty-stderr expectation.
# Used by T-GCF-LCF-20.
_lcf_run_source_twice() {
  local _lib="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh"

  # shellcheck disable=SC2016 # expanded by the inner bash
  _lcf_run_with_modify_add bash -c '
    unset GET_CHANGED_FILES_LIB_LOADED
    for _n in first second; do
      . "$1" || {
        printf "%s source returned %s\n" "$_n" "$?" >&2
        exit 1
      }
    done
    list_changed_files "$2" "$3"
  ' bash "$_lib"
}

##
# before: a.sh / after: a.sh renamed to b.sh with "git mv". Used by
# T-GCF-LCF-02.
_lcf_run_rename() {
  local _repo _before _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before a.sh one)" || _setup_failed lcf || return
  gf_git "$_repo" mv a.sh b.sh || _setup_failed lcf || return
  _after="$(_lcf_commit_staged "$_repo" after)" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_before" "$_after"
}

##
# before: <base> (through the work tree) / after: each <path> added with the
# content "doc", registered in the index directly in the given order. Shared
# by _lcf_run_add_index_file and _lcf_run_add_paths.
# @arg $1 base    — file of the before commit
# @arg $2 content — content of <base>
# @arg $3.. paths — paths added by the after commit, in the order of addition
_lcf_run_add_index_paths() {
  local _base="$1" _content="$2" _repo _before _after _path
  local -a _pairs=()
  shift 2

  for _path in "$@"; do
    _pairs+=("$_path" doc)
  done
  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before "$_base" "$_content")" || _setup_failed lcf || return
  _after="$(_lcf_commit_index_files "$_repo" after "${_pairs[@]}")" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_before" "$_after"
}

##
# before: a.sh / after: <path> added (registered in the index directly). Used
# by T-GCF-LCF-03 (non-ASCII path) and T-GCF-LCF-04 (path with a space).
# @arg $1 path — special file name added by the after commit
_lcf_run_add_index_file() {
  _lcf_run_add_index_paths a.sh one "$1"
}

##
# Write each <path> to ${GF_TMP_ROOT}/paths.txt (terminated by NUL) in the
# given order and build expected.txt from it; then before: base.md / after:
# the paths added in that order (registered in the index directly). Used by
# T-GCF-LCF-06 and by T-GCF-LCF-16 to T-GCF-LCF-19 (a path with a double
# quote, a backslash, a TAB and an LF).
# @arg $@ paths — paths added by the after commit, in the order of addition
_lcf_run_add_paths() {
  printf '%s\0' "$@" >"${GF_TMP_ROOT}/paths.txt" || _setup_failed lcf || return
  _lcf_write_expected || _setup_failed lcf || return
  _lcf_run_add_index_paths base.md base "$@"
}

##
# A single commit with a.sh and b.sh; before is the empty tree SHA
# (_EMPTY_TREE_SHA, never written to the object store) and after is HEAD.
# Used by T-GCF-LCF-05.
_lcf_run_empty_tree() {
  local _repo _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _after="$(_lcf_commit_files "$_repo" initial a.sh one b.sh two)" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_EMPTY_TREE_SHA" "$_after"
}

##
# A single commit with a.sh; before and after are both HEAD. Used by
# T-GCF-LCF-07.
_lcf_run_same_tree() {
  local _repo _head

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _head="$(_lcf_commit_files "$_repo" initial a.sh one)" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_head" "$_head"
}

##
# before: old.sh and keep.sh / after: only old.sh deleted with "git rm". Used
# by T-GCF-LCF-08.
_lcf_run_delete_only() {
  local _repo _before _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before old.sh one keep.sh two)" || _setup_failed lcf || return
  gf_git "$_repo" rm -q old.sh || _setup_failed lcf || return
  _after="$(_lcf_commit_staged "$_repo" after)" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_before" "$_after"
}

##
# before: link as a regular file (100644) / after: link re-registered in the
# index as a symbolic link entry (120000) with the same blob ("target"), so
# only its type changes. No real symbolic link is created in the work tree.
# Used by T-GCF-LCF-09.
_lcf_run_type_change() {
  local _repo _before _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_index_files "$_repo" before link target)" || _setup_failed lcf || return
  _after="$(_lcf_commit_index_entries "$_repo" after 120000 link target)" || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_before" "$_after"
}

##
# before: a.sh / a middle commit: b.md added / after: a.sh modified / then
# HEAD: c.txt added and a.sh modified again. after is not HEAD and before is
# not after's parent, so the list holds the middle commit's b.md but not
# HEAD's c.txt. Used by T-GCF-LCF-21.
_lcf_run_between() {
  local _repo _before _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before a.sh one)" || _setup_failed lcf || return
  _lcf_commit_files "$_repo" middle b.md doc >/dev/null || _setup_failed lcf || return
  _after="$(_lcf_commit_files "$_repo" after a.sh two)" || _setup_failed lcf || return
  _lcf_commit_files "$_repo" head c.txt late a.sh three >/dev/null || _setup_failed lcf || return
  gf_run_in "$_repo" list_changed_files "$_before" "$_after"
}

##
# A single commit with a.sh; before is <before> (not a commit of the
# repository) and after is HEAD, whose OID is written to
# ${GF_TMP_ROOT}/after.txt for _lcf_ends_with_list_error, since the It cannot
# see the OID created inside the fixture. Before list_changed_files, the same
# git diff command as the library's (with --end-of-options, so <before> is
# never taken as an option) is run directly in the repository and its stderr
# is written to ${GF_TMP_ROOT}/git-stderr.txt for
# _lcf_has_git_output_before_last; that run succeeding is a setup failure.
# Used by T-GCF-LCF-10 (_MISSING_SHA), T-GCF-LCF-11 (a value with % and LF),
# T-GCF-LCF-12 (a value with CR) and T-GCF-LCF-22 (a value starting with "-").
# @arg $1 before — commit-ish that git diff cannot resolve
_lcf_run_bad_before() {
  local _repo _after

  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _after="$(_lcf_commit_files "$_repo" initial a.sh one)" || _setup_failed lcf || return
  printf '%s\n' "$_after" >"${GF_TMP_ROOT}/after.txt" || _setup_failed lcf || return
  if gf_run_in "$_repo" git -c core.quotePath=false diff --name-only --diff-filter=ACMR --end-of-options "$1" "$_after" \
    >/dev/null 2>"${GF_TMP_ROOT}/git-stderr.txt"; then
    _setup_failed lcf
    return
  fi
  gf_run_in "$_repo" list_changed_files "$1" "$_after"
}

##
# Build expected.txt from the already written and checked paths.txt; then
# before: base.md / after: every path of paths.txt added (registered in the
# index with one --index-info call), and run list_changed_files, with
# LC_ALL=<locale> set for that run only when <locale> is given.
# The fixture build time (from <start>) and the run time are recorded for
# <case> with _lcf_record_timing (only when GCF_FIXTURE_TIMING is set).
# Shared by _lcf_run_list_of_bytes and _lcf_run_utf8_list_of_bytes.
# @arg $1 case   — Test ID of the case, for the timing record
# @arg $2 start  — time before writing paths.txt (_lcf_now_us)
# @arg $3 locale — LC_ALL of the caller of list_changed_files (optional)
_lcf_run_paths_file() {
  local _case="$1" _start="$2" _locale="${3:-}" _repo _before _after _built _done _status=0

  _lcf_write_expected || _setup_failed lcf || return
  _repo="$(gf_init_repo lcf)" || _setup_failed lcf || return
  _before="$(_lcf_commit_files "$_repo" before base.md base)" || _setup_failed lcf || return
  _after="$(_lcf_commit_index_paths_file "$_repo" after)" || _setup_failed lcf || return
  _lcf_now_us _built
  if [ -n "$_locale" ]; then
    LC_ALL="$_locale" gf_run_in "$_repo" list_changed_files "$_before" "$_after" || _status=$?
  else
    gf_run_in "$_repo" list_changed_files "$_before" "$_after" || _status=$?
  fi
  _lcf_now_us _done
  _lcf_record_timing "$_case" "$_start" "$_built" "$_done"
  return "$_status"
}

##
# Write paths.txt with ASCII paths whose LF-joined list is exactly <bytes>
# bytes, check that count before running, and run it with
# _lcf_run_paths_file. Used by T-GCF-LCF-13 (120001 bytes) and T-GCF-LCF-14
# (120000 bytes).
# @arg $1 case  — Test ID of the case, for the timing record
# @arg $2 bytes — byte count of the LF-joined list
_lcf_run_list_of_bytes() {
  local _start

  _lcf_now_us _start
  _lcf_write_paths_of_bytes "$2" || _setup_failed lcf || return
  _lcf_paths_have_bytes "$2" || _setup_failed lcf || return
  _lcf_run_paths_file "$1" "$_start"
}

##
# Write paths.txt with paths holding the 3-byte character "日" whose LF-joined
# list is exactly <bytes> bytes but fewer than <chars> characters under
# C.UTF-8, check both counts before running, and run it with
# _lcf_run_paths_file under the caller's LC_ALL=C.UTF-8. Used by
# T-GCF-LCF-15 (120001 bytes, fewer than 120000 characters).
# @arg $1 case  — Test ID of the case, for the timing record
# @arg $2 bytes — byte count of the LF-joined list
# @arg $3 chars — exclusive upper bound of its character count
_lcf_run_utf8_list_of_bytes() {
  local _start

  _lcf_now_us _start
  _lcf_write_paths_of_bytes "$2" '日' || _setup_failed lcf || return
  _lcf_paths_have_bytes "$2" || _setup_failed lcf || return
  _lcf_paths_have_fewer_chars "$3" || _setup_failed lcf || return
  _lcf_run_paths_file "$1" "$_start" C.UTF-8
}

Describe 'get-changed-files.lib.sh'
  BeforeEach 'gf_setup'
  AfterEach 'gf_cleanup'

  ##
  # list_changed_files: print the files added, copied, modified or renamed
  # between <before> and <after> (git diff --diff-filter=ACMR), one per line,
  # in git's order, without a trailing LF.
  # Scenarios: modified and added files are returned; a rename returns only
  # the new path; a non-ASCII path is returned unquoted; a path with a space
  # is returned as is; an empty tree before returns every file of after; the
  # list keeps git's (byte) order, not the order of addition; the same tree
  # on both sides returns an empty list; a diff with only deletions returns an
  # empty list; a type change (regular file to symbolic link) is not listed;
  # a commit missing from the repository fails with git's output followed by
  # one error line; a before starting with "-" is not taken as an option and
  # fails with the error line; a list over 120000 bytes fails with one error
  # line; a list of exactly 120000 bytes is accepted; the list is counted in bytes
  # even when the caller uses a UTF-8 locale; a path with a double quote, a
  # backslash, a TAB or an LF is returned in git's quoted form, on one line;
  # the library sourced twice still loads and lists the files; an after that
  # is not HEAD returns only the changes between before and after, those of
  # the commits in between included.
  Describe 'list_changed_files'
    # 正常系: the list of changed files
    Context 'When: 正常系'
      It '[Normal] T-GCF-LCF-01: 変更と追加のファイルを返す'
        When call _lcf_run_modify_add
        The status should equal 0
        The stdout should equal $'a.sh\nb.md'
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-02: リネームでは新しいパスだけを返す'
        When call _lcf_run_rename
        The status should equal 0
        The stdout should equal 'b.sh'
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-03: 非 ASCII 文字を含むパスは引用表記にしない'
        When call _lcf_run_add_index_file 'docs/日本語.md'
        The status should equal 0
        The stdout should equal 'docs/日本語.md'
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-04: 空白を含むパスをそのまま返す'
        When call _lcf_run_add_index_file 'my file.sh'
        The status should equal 0
        The stdout should equal 'my file.sh'
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-05: before が空ツリー SHA なら after の全ファイルを返す'
        When call _lcf_run_empty_tree
        The status should equal 0
        The stdout should equal $'a.sh\nb.sh'
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-06: 一覧は git の出力順のまま返す'
        When call _lcf_run_add_paths z.sh a.sh dir/b.sh
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-07: 同じツリーなら空の一覧で成功する'
        When call _lcf_run_same_tree
        The status should equal 0
        The entire stdout should equal ""
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-08: 削除だけの差分は空の一覧になる'
        When call _lcf_run_delete_only
        The status should equal 0
        The entire stdout should equal ""
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-09: 型の変更 (通常ファイル → シンボリックリンク) は含めない'
        When call _lcf_run_type_change
        The status should equal 0
        The entire stdout should equal ""
        The stderr should equal ""
      End

      It '[Normal] T-GCF-LCF-21: before と after の間の差分だけを返す'
        When call _lcf_run_between
        The status should equal 0
        The stdout should equal $'a.sh\nb.md'
        The stderr should equal ""
      End
    End

    # 異常系: git diff fails, or the list exceeds the byte limit
    Context 'When: 異常系'
      It '[Error] T-GCF-LCF-10: 不在のコミットでは git の出力の後にエラーを 1 行出す'
        When call _lcf_run_bad_before "$_MISSING_SHA"
        The status should equal 1
        The entire stdout should equal ""
        The entire stderr should satisfy _lcf_ends_with_list_error "$_MISSING_SHA"
        The entire stderr should satisfy _lcf_has_git_output_before_last
      End

      It '[Error] T-GCF-LCF-11: エラーの値の % と LF をエンコードする'
        When call _lcf_run_bad_before $'a%b\nc'
        The status should equal 1
        The entire stderr should satisfy _lcf_ends_with_list_error 'a%25b%0Ac'
      End

      It '[Error] T-GCF-LCF-12: エラーの値の CR をエンコードする'
        When call _lcf_run_bad_before $'a\rb'
        The status should equal 1
        The entire stderr should satisfy _lcf_ends_with_list_error 'a%0Db'
        The entire stderr should satisfy _lcf_last_line_has_no_cr
      End

      It '[Error] T-GCF-LCF-13: 120001 バイトの一覧はエラーにする'
        When call _lcf_run_list_of_bytes T-GCF-LCF-13 120001
        The status should equal 1
        The entire stdout should equal ""
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120001')"
      End

      It '[Error] T-GCF-LCF-22: - で始まる before をオプションとして解釈しない'
        When call _lcf_run_bad_before "--output=${GF_TMP_ROOT}/out.txt"
        The status should equal 1
        The entire stdout should equal ""
        The entire stderr should satisfy _lcf_ends_with_list_error "--output=${GF_TMP_ROOT}/out.txt"
        The path "${GF_TMP_ROOT}/out.txt" should not be exist
      End
    End

    # エッジケース: the byte limit boundary, and paths git prints quoted
    Context 'When: エッジケース'
      It '[Edge] T-GCF-LCF-14: 120000 バイトちょうどの一覧は受け付ける'
        When call _lcf_run_list_of_bytes T-GCF-LCF-14 120000
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stderr should equal ""
      End

      It '[Edge] T-GCF-LCF-15: UTF-8 のロケールでもバイト数で数える'
        When call _lcf_run_utf8_list_of_bytes T-GCF-LCF-15 120001 120000
        The status should equal 1
        The entire stdout should equal ""
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120001')"
      End

      It '[Edge] T-GCF-LCF-16: ダブルクオートを含むパスは引用表記で返す'
        When call _lcf_run_add_paths 'a"b.sh'
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stdout should equal '"a\"b.sh"'
        The stderr should equal ""
      End

      It '[Edge] T-GCF-LCF-17: バックスラッシュを含むパスは引用表記で返す'
        When call _lcf_run_add_paths 'a\b.sh'
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stdout should equal '"a\\b.sh"'
        The stderr should equal ""
      End

      It '[Edge] T-GCF-LCF-18: タブを含むパスは引用表記で返す'
        When call _lcf_run_add_paths $'a\tb.sh'
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stdout should equal '"a\tb.sh"'
        The stderr should equal ""
      End

      It '[Edge] T-GCF-LCF-19: LF を含むパスは引用表記の 1 行で返す'
        When call _lcf_run_add_paths $'a\nb.sh'
        The status should equal 0
        The entire stdout should satisfy _lcf_matches_expected
        The stdout should equal '"a\nb.sh"'
        The lines of stdout should equal 1
        The stderr should equal ""
      End

      It '[Edge] T-GCF-LCF-20: 2 回読み込んでも呼べる'
        When call _lcf_run_source_twice
        The status should equal 0
        The stdout should equal $'a.sh\nb.md'
        The stderr should equal ""
      End
    End
  End
End
