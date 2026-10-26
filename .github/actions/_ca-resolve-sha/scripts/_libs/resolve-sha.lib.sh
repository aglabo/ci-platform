#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh
# @(#) : helper functions for the _ca-resolve-sha composite action
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

[ -n "${RESOLVE_SHA_LIB_LOADED:-}" ] && return 0
RESOLVE_SHA_LIB_LOADED=1

# Directory of this library; used to source shared libraries relative to it
_RS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_libs/validation.lib.sh
# shellcheck disable=SC1091
. "${_RS_LIB_DIR}/../../../_libs/validation.lib.sh" || return 1
# shellcheck source=.github/actions/_libs/output.lib.sh
# shellcheck disable=SC1091
. "${_RS_LIB_DIR}/../../../_libs/output.lib.sh" || return 1

# SHA of git's empty tree object; used as the base when no parent commit exists
RS_EMPTY_TREE_SHA="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
# 40-digit zero OID; the push event before of a newly created branch
RS_ZERO_OID="0000000000000000000000000000000000000000"

##
# @description Emit a GitHub Actions error annotation. The form is chosen by
#              argument count, not by whether the value is empty:
#              - 3 arguments (normal form):
#                "::error::<target>: <problem> (got: '<value>')"
#                (an explicitly passed "" still uses this form)
#              - 2 arguments (empty form; <problem> is not printed):
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
rs_error() {
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

##
# @description Confirm the commit-count input. An explicit empty string uses
#              the default value 1; any other value, including whitespace,
#              is used as is without trimming. The value must be a positive
#              integer not greater than 1000 (checked by validate_positive_int,
#              which checks the digit count before the numeric compare).
# @arg $1 value — raw commit-count input
# @stdout the confirmed commit count as one line; nothing on error
# @stderr one ::error::commit-count line on error
# @return 0 on success, 1 on an invalid value
normalize_commit_count() {
  local _value="${1:-1}"
  if ! validate_positive_int "$_value" 1000; then
    rs_error commit-count "must be a positive integer not greater than 1000" "$_value"
    return 1
  fi
  printf '%s\n' "$_value"
}

##
# @description Decide whether the before-sha / after-sha override is used.
#              Both inputs empty means no override. Exactly one input
#              specified is an error targeting the empty side (before any
#              format check). Otherwise both must be full 40-character
#              lowercase hex OIDs (before-sha is checked before after-sha);
#              then the override is used. Only an exact "" counts as empty
#              (no trimming).
# @arg $1 before — raw before-sha input
# @arg $2 after  — raw after-sha input
# @stdout "none" when both inputs are empty, "override" when both are
#         valid OIDs; nothing on error
# @stderr one ::error::before-sha / ::error::after-sha line on error
# @return 0 on success, 1 when exactly one input is specified or an input
#         is not a full 40-character lowercase hex OID
validate_override() {
  local _before="$1" _after="$2"
  # R-IN-005: both empty -> no override (mutually exclusive with R-IN-004,
  # so checking it first keeps the spec's rule outcome)
  if [[ -z "$_before$_after" ]]; then
    printf 'none\n'
    return 0
  fi
  # R-IN-004: exactly one side specified -> error on the empty side
  if [[ -z "$_after" ]]; then
    rs_error after-sha
    return 1
  fi
  if [[ -z "$_before" ]]; then
    rs_error before-sha
    return 1
  fi
  # R-IN-006: both specified -> each must be a full lowercase hex OID
  local _oid_pattern='^[0-9a-f]{40}$'
  local _oid_problem="must be a full 40-character lowercase hex commit SHA"
  if [[ ! "$_before" =~ $_oid_pattern ]]; then
    rs_error before-sha "$_oid_problem" "$_before"
    return 1
  fi
  if [[ ! "$_after" =~ $_oid_pattern ]]; then
    rs_error after-sha "$_oid_problem" "$_after"
    return 1
  fi
  # R-IN-007: both valid OIDs -> override
  printf 'override\n'
}

##
# @description Decide whether the repository of the current working directory
#              is a partial clone, from git config alone (no object access, so
#              no lazy fetch is triggered). Matches extensions.partialclone or
#              remote.<name>.promisor (git compares keys case-insensitively);
#              the output of git config is discarded and rs_error is never
#              called, so the caller reports any error.
# @stdout (none)
# @stderr (none)
# @return 0 when the repository is a partial clone,
#         1 when it is not (including a non-git directory),
#         2 when git config cannot be read (e.g. a broken .git/config)
is_partial_clone() {
  local _rc
  git config --get-regexp '^(extensions\.partialclone|remote\..*\.promisor)$' >/dev/null 2>&1
  _rc=$?
  case "$_rc" in
  0) return 0 ;;
  1) return 1 ;;
  *) return 2 ;;
  esac
}

##
# @description Decide whether <sha> names an existing commit object in the
#              repository of the current working directory
#              (git cat-file -e "<sha>^{commit}"). The output of git is
#              discarded and rs_error is never called, so the caller reports
#              any error.
# @arg $1 sha — object name to check
# @stdout (none)
# @stderr (none)
# @return 0 when <sha> names an existing commit object,
#         non-zero otherwise (including "", a valid-format OID absent from
#         the repository, the 40-digit zero OID, and non-commit objects such
#         as RS_EMPTY_TREE_SHA)
is_commit() {
  git cat-file -e "${1}^{commit}" >/dev/null 2>&1
}

##
# @description Confirm that <sha> names an existing commit object in the
#              repository of the current working directory, in this order:
#              R-RES-021: an empty <sha> is an error (empty form);
#              R-RES-024: a <sha> that is not a commit (checked by is_commit)
#              is an error "commit not found" with <sha> as the value;
#              R-RES-025: otherwise succeed. The empty tree SHA
#              (RS_EMPTY_TREE_SHA) is not exempt. Errors use rs_error with
#              <field> as the target.
# @arg $1 sha   — object name to verify
# @arg $2 field — input or environment variable name used as the error target
#                 (e.g. "before-sha", "GITHUB_BASE_SHA")
# @stdout (none)
# @stderr nothing on success; on error one ::error::<field> line, either
#         "value must not be empty" (empty <sha>) or
#         "commit not found (got: '<sha>')"
# @return 0 when <sha> names an existing commit, 1 otherwise
verify_commit() {
  local _sha="$1" _field="$2"
  # R-RES-021
  if [[ -z "$_sha" ]]; then
    rs_error "$_field"
    return 1
  fi
  # R-RES-024
  if ! is_commit "$_sha"; then
    rs_error "$_field" "commit not found" "$_sha"
    return 1
  fi
  # R-RES-025
  return 0
}

##
# @description Count the commits on the first-parent chain from <head-oid>
#              (git rev-list --first-parent --count) in the repository of the
#              current working directory. git's own stderr is discarded and
#              rs_error is never called, so the caller reports any error.
# @arg $1 head-oid — commit OID to count from
# @stdout the count as one line when it is a non-negative integer; nothing
#         otherwise
# @stderr (none)
# @return 0 when the count was obtained and is all digits, 1 when git fails or
#         its output is not all digits
_rs_first_parent_count() {
  local _count
  _count="$(git rev-list --first-parent --count "$1" 2>/dev/null)" || return 1
  [[ "$_count" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$_count"
}

##
# @description Resolve the HEAD~N range of the repository of the current
#              working directory, in this fixed order:
#              R-RES-011: resolve HEAD as a commit once (an error when it
#              cannot be resolved); R-RES-012: when "<head>~<n>" resolves to a
#              commit, use it as before (fallback-head-n); R-RES-013: an error
#              when the first-parent commit count C cannot be obtained;
#              R-RES-014: when C <= <n>, use the empty tree (empty-tree);
#              R-RES-015: otherwise an error. Only the first-parent chain is
#              followed ("~", never "^<k>"). after is always the HEAD OID
#              resolved in step 1; HEAD is never referenced again. git's own
#              stderr is discarded. <n> is used as is (already validated by
#              normalize_commit_count).
# @arg $1 n — positive integer commit count
# @stdout "<before> <after> <resolution>" as one line on success;
#         nothing on error
# @stderr nothing on success; one ::error:: line on error
# @return 0 on success, 1 on error
resolve_head_n() {
  local _n="$1" _head _before _count
  # R-RES-011
  if ! _head="$(git rev-parse --verify -q "HEAD^{commit}" 2>/dev/null)"; then
    rs_error HEAD "cannot be resolved as a commit" HEAD
    return 1
  fi
  # R-RES-012
  if _before="$(git rev-parse --verify -q "${_head}~${_n}^{commit}" 2>/dev/null)"; then
    printf '%s %s %s\n' "$_before" "$_head" fallback-head-n
    return 0
  fi
  # R-RES-013
  if ! _count="$(_rs_first_parent_count "$_head")"; then
    rs_error "HEAD~N" "cannot count first-parent commits" "$_n"
    return 1
  fi
  # R-RES-014
  if ((_count <= _n)); then
    printf '%s %s %s\n' "$RS_EMPTY_TREE_SHA" "$_head" empty-tree
    return 0
  fi
  # R-RES-015
  rs_error "HEAD~N" "cannot be resolved although history exists" "$_n"
  return 1
}

##
# @description Check that a push event without an override can be resolved
#              (R-RES-009). The check applies only when <event> is "push" and
#              the override is not used (<ov-before> or <ov-after> is empty);
#              otherwise it always succeeds. Checked in this order:
#              a <deleted> of "true" (a ref deletion push) is an error with
#              <deleted> as the value; then a <ref> outside "refs/heads/"
#              (e.g. a tag push) is an error with <ref> as the value.
# @arg $1 event     — GITHUB_EVENT_NAME
# @arg $2 ov-before — before-sha override input
# @arg $3 ov-after  — after-sha override input
# @arg $4 ref       — GITHUB_REF
# @arg $5 deleted   — GITHUB_EVENT_DELETED ("true" / "false")
# @stdout (none)
# @stderr nothing on success; one ::error::GITHUB_EVENT_DELETED or
#         ::error::GITHUB_REF line on error
# @return 0 when the check passes or does not apply, 1 on error
_rs_check_push_event() {
  local _event="$1" _ov_before="$2" _ov_after="$3" _ref="$4" _deleted="$5"
  [[ "$_event" == push ]] || return 0
  [[ -z "$_ov_before" || -z "$_ov_after" ]] || return 0
  if [[ "$_deleted" == true ]]; then
    rs_error GITHUB_EVENT_DELETED "a ref deletion push has no commit range" "$_deleted"
    return 1
  fi
  if [[ "$_ref" != refs/heads/* ]]; then
    rs_error GITHUB_REF "must be a branch ref (refs/heads/*) for a push" "$_ref"
    return 1
  fi
  return 0
}

##
# @description Check that the repository of the current working directory can
#              be resolved, from git config alone (checked by is_partial_clone,
#              so no object is accessed), in this order:
#              R-RES-010: git config that cannot be read (is_partial_clone
#              returns 2, e.g. a broken .git/config) is an error;
#              R-RES-008: a partial clone (is_partial_clone returns 0) is an
#              error. Both use the working directory as the value; a
#              repository that is not a partial clone (return 1) passes.
# @stdout (none)
# @stderr nothing on success; one ::error::repository line on error
# @return 0 when the check passes, 1 on error
_rs_check_repository() {
  is_partial_clone
  case "$?" in
  2)
    # R-RES-010
    rs_error repository "git config cannot be read" "$PWD"
    return 1
    ;;
  0)
    # R-RES-008
    rs_error repository "partial clone is not supported" "$PWD"
    return 1
    ;;
  esac
  return 0
}

##
# @description Use the before-sha / after-sha override as the range
#              (R-RES-002). <ov-before> and then <ov-after> must each name an
#              existing commit in the repository of the current working
#              directory (checked by verify_commit with "before-sha" /
#              "after-sha" as the target, R-RES-024); <ov-after> is not
#              checked when <ov-before> fails.
# @arg $1 ov-before — before-sha override input (non-empty)
# @arg $2 ov-after  — after-sha override input (non-empty)
# @stdout "<ov-before> <ov-after> override" as one line on success;
#         nothing on error
# @stderr nothing on success; one ::error::before-sha or ::error::after-sha
#         line on error
# @return 0 on success, 1 on error
_rs_resolve_override() {
  verify_commit "$1" before-sha || return 1
  verify_commit "$2" after-sha || return 1
  printf '%s %s %s\n' "$1" "$2" override
}

##
# @description Resolve the range of a push event without the override, in
#              this order:
#              R-RES-003: an empty or 40-digit zero (RS_ZERO_OID) <ev-before>
#              is resolved by resolve_head_n <n> (fallback-head-n);
#              R-RES-004: an <ev-before> that is not a commit (checked by
#              is_commit) is also resolved by resolve_head_n <n>, without
#              reporting an error;
#              R-RES-005: otherwise <ev-after> must name an existing commit
#              (checked by verify_commit with "GITHUB_AFTER_SHA" as the
#              target; an empty <ev-after> is the empty form, R-RES-021) and
#              the event payload range (<ev-before> <ev-after>) is used
#              (event). A failed check prints no HEAD~N fallback.
# @arg $1 n         — commit count (already validated by normalize_commit_count)
# @arg $2 ev-before — before commit of the push event payload
# @arg $3 ev-after  — after commit of the push event payload (GITHUB_AFTER_SHA)
# @stdout "<before> <after> <resolution>" as one line on success;
#         nothing on error
# @stderr nothing on success; one ::error:: line on error (from resolve_head_n,
#         or ::error::GITHUB_AFTER_SHA from verify_commit)
# @return 0 on success, 1 on error
_rs_resolve_push() {
  local _n="$1" _ev_before="$2" _ev_after="$3"
  # R-RES-003 -> R-RES-004
  if [[ -z "$_ev_before" || "$_ev_before" == "$RS_ZERO_OID" ]] || ! is_commit "$_ev_before"; then
    resolve_head_n "$_n"
    return
  fi
  # R-RES-005
  verify_commit "$_ev_after" GITHUB_AFTER_SHA || return 1
  printf '%s %s %s\n' "$_ev_before" "$_ev_after" event
}

##
# @description Resolve the range of a pull_request event (R-RES-006):
#              <base> must name an existing commit (checked by verify_commit
#              with "GITHUB_BASE_SHA" as the target; an empty <base> is the
#              empty form, R-RES-021), then <head> must name an existing
#              commit (checked by verify_commit with "GITHUB_HEAD_SHA" as the
#              target; <head> is not checked when <base> fails), then <base>
#              and <head> are used as the range (event).
# @arg $1 base — pull request base commit (GITHUB_BASE_SHA)
# @arg $2 head — pull request head commit (GITHUB_HEAD_SHA)
# @stdout "<base> <head> event" as one line on success; nothing on error
# @stderr nothing on success; one ::error::GITHUB_BASE_SHA or
#         ::error::GITHUB_HEAD_SHA line on error
# @return 0 on success, 1 on error
_rs_resolve_pull_request() {
  verify_commit "$1" GITHUB_BASE_SHA || return 1
  verify_commit "$2" GITHUB_HEAD_SHA || return 1
  printf '%s %s %s\n' "$1" "$2" event
}

##
# @description Resolve the before / after commit range for the triggering
#              event in the repository of the current working directory.
#              R-RES-001: an empty <event> is an error (empty form), checked
#              before any other rule.
#              R-RES-009: for a push without the override, a <deleted> of
#              "true" is an error, then a <ref> outside "refs/heads/" is an
#              error (both checked by _rs_check_push_event).
#              R-RES-010: a working directory whose git config cannot be read
#              is an error, then R-RES-008: a partial clone working directory
#              is an error (both checked by _rs_check_repository), before any
#              object access.
#              R-RES-002: when both <ov-before> and <ov-after> are non-empty,
#              they are used as the range (override); <ov-before> and then
#              <ov-after> must name existing commits (all checked by
#              _rs_resolve_override).
#              R-RES-003 -> R-RES-004 -> R-RES-005: a push is resolved by
#              _rs_resolve_push (HEAD~N for an empty, 40-digit zero or
#              non-commit <ev-before>, otherwise the event payload range
#              after verifying <ev-after> as GITHUB_AFTER_SHA).
#              R-RES-006: a pull_request is resolved by
#              _rs_resolve_pull_request (<base> and <head>, event, after
#              verifying <base> as GITHUB_BASE_SHA and then <head> as
#              GITHUB_HEAD_SHA).
#              R-RES-007: any other event is resolved by resolve_head_n <n>.
# @arg $1  event    — GITHUB_EVENT_NAME (e.g. "push", "pull_request")
# @arg $2  n         — commit count (already validated by normalize_commit_count)
# @arg $3  ov-before — before-sha override input
# @arg $4  ov-after  — after-sha override input
# @arg $5  ev-before — before commit of the push event payload
# @arg $6  ev-after  — after commit of the push event payload (GITHUB_AFTER_SHA)
# @arg $7  base      — pull request base commit (GITHUB_BASE_SHA)
# @arg $8  head      — pull request head commit (GITHUB_HEAD_SHA)
# @arg $9  ref       — GITHUB_REF
# @arg $10 deleted   — GITHUB_EVENT_DELETED ("true" / "false")
# @stdout "<before> <after> <resolution>" as one line on success;
#         nothing on error
# @stderr nothing on success; one ::error:: line on error
#         (e.g. "::error::GITHUB_EVENT_NAME: value must not be empty")
# @return 0 on success, 1 on error
resolve_sha() {
  local _event="$1" _ov_before="$3" _ov_after="$4"
  # R-RES-001
  if [[ -z "$_event" ]]; then
    rs_error GITHUB_EVENT_NAME
    return 1
  fi
  # R-RES-009
  _rs_check_push_event "$_event" "$_ov_before" "$_ov_after" "$9" "${10}" || return 1
  # R-RES-010 -> R-RES-008
  _rs_check_repository || return 1
  # R-RES-002
  if [[ -n "$_ov_before" && -n "$_ov_after" ]]; then
    _rs_resolve_override "$_ov_before" "$_ov_after"
    return
  fi
  case "$_event" in
  push) _rs_resolve_push "$2" "$5" "$6" ;;            # R-RES-003 -> R-RES-005
  pull_request) _rs_resolve_pull_request "$7" "$8" ;; # R-RES-006
  *) resolve_head_n "$2" ;;                           # R-RES-007
  esac
}

##
# @description Check the step output file path (GITHUB_OUTPUT) before
#              anything is written. Checked in this order: an empty <file>
#              is an error (R-OUT-003); then a <file> that is a directory
#              is an error with <file> as the value (R-OUT-004).
# @arg $1 file — output file path (GITHUB_OUTPUT)
# @stdout (none)
# @stderr nothing on success; one ::error::GITHUB_OUTPUT line on error
# @return 0 when the check passes, 1 on error
_rs_check_output_file() {
  # R-OUT-003
  if [[ -z "$1" ]]; then
    rs_error GITHUB_OUTPUT
    return 1
  fi
  # R-OUT-004
  if [[ -d "$1" ]]; then
    rs_error GITHUB_OUTPUT "is not a writable file" "$1"
    return 1
  fi
}

##
# @description Check one step output value before anything is written: a
#              <value> containing CR or LF is an error with the output key
#              <key> as the target (R-OUT-005).
# @arg $1 key   — step output key (e.g. "before_sha")
# @arg $2 value — value to be written for <key>
# @stdout (none)
# @stderr nothing on success; one ::error::<key> line on error
# @return 0 when the check passes, 1 on error
_rs_check_output_value() {
  if [[ "$2" == *[$'\r\n']* ]]; then
    rs_error "$1" "must not contain CR or LF" "$2"
    return 1
  fi
}

##
# @description Check every step output value before anything is written, in
#              the order before_sha -> after_sha -> resolution (R-OUT-005);
#              stops at the first value containing CR or LF.
# @arg $1 before     — value for before_sha
# @arg $2 after      — value for after_sha
# @arg $3 resolution — value for resolution
# @stdout (none)
# @stderr nothing on success; one ::error::<key> line for the first rejected value
# @return 0 when every value passes, 1 on error
_rs_check_output_values() {
  _rs_check_output_value before_sha "$1" &&
    _rs_check_output_value after_sha "$2" &&
    _rs_check_output_value resolution "$3"
}

##
# @description Check the resolution value before anything is written: a
#              <resolution> that is not one of the known values (override,
#              event, fallback-head-n, empty-tree) is an error with the
#              output key "resolution" as the target (R-OUT-006).
#              The comparison is case-sensitive.
# @arg $1 resolution — value for resolution
# @stdout (none)
# @stderr nothing on success; one ::error::resolution line on error
# @return 0 when the check passes, 1 on error
_rs_check_resolution() {
  case "$1" in
  override | event | fallback-head-n | empty-tree) ;;
  *)
    rs_error resolution "is not a known resolution" "$1"
    return 1
    ;;
  esac
}

##
# @description Append one step output "<key>=<value>" to <file> with
#              write_output. A non-0 return of write_output (1 or 2) is an
#              error with the output key <key> as the target (R-OUT-008).
# @arg $1 file  — output file path (GITHUB_OUTPUT)
# @arg $2 key   — step output key (e.g. "before_sha")
# @arg $3 value — value to be written for <key>
# @stdout (none)
# @stderr nothing on success; one ::error::<key> line on error
# @return 0 on success, 1 when the write fails
_rs_write_output() {
  write_output "$1" "$2" "$3" && return 0
  rs_error "$2" "failed to write" "$3"
  return 1
}

##
# @description Append every step output to <file> in the order before_sha ->
#              after_sha -> resolution (R-OUT-007); stops immediately at the
#              first failing write, leaving the lines already written
#              (R-OUT-008).
# @arg $1 file       — output file path (GITHUB_OUTPUT)
# @arg $2 before     — value for before_sha
# @arg $3 after      — value for after_sha
# @arg $4 resolution — value for resolution
# @stdout (none)
# @stderr nothing on success; one ::error::<key> line for the first failed write
# @return 0 when every write succeeds, 1 on error
_rs_write_outputs() {
  _rs_write_output "$1" before_sha "$2" &&
    _rs_write_output "$1" after_sha "$3" &&
    _rs_write_output "$1" resolution "$4"
}

##
# @description Append the resolved range to the step output file (GITHUB_OUTPUT)
#              as "before_sha=<before>", "after_sha=<after>" and
#              "resolution=<resolution>", in this order (R-OUT-007), each
#              written by write_output. <file> is checked by
#              _rs_check_output_file before anything is written (R-OUT-003,
#              R-OUT-004); then <before>, <after> and <resolution> are checked
#              in this order and a value containing CR or LF is rejected
#              (R-OUT-005); then an unknown <resolution> is rejected by
#              _rs_check_resolution (R-OUT-006). The writes are done by
#              _rs_write_outputs, which stops immediately at the first
#              write_output failure with one ::error::<key> line (R-OUT-008).
# @arg $1 file       — output file path (GITHUB_OUTPUT)
# @arg $2 before     — before commit (or RS_EMPTY_TREE_SHA)
# @arg $3 after      — after commit
# @arg $4 resolution — how the range was resolved (e.g. "event")
# @stdout (none)
# @stderr one ::error:: line when <file> is empty or is a directory, or when
#         a value contains CR or LF, or when <resolution> is unknown, or when
#         a write fails
# @return 0 on success, 1 when an argument is rejected or a write fails
emit_outputs() {
  _rs_check_output_file "$1" || return 1
  # R-OUT-005
  _rs_check_output_values "$2" "$3" "$4" || return 1
  # R-OUT-006
  _rs_check_resolution "$4" || return 1
  # R-OUT-007, R-OUT-008
  _rs_write_outputs "$1" "$2" "$3" "$4" || return 1
}
