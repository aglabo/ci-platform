#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Functional test suite for resolve-sha.sh
# Module: composite-action/resolve-sha (test_scope RS)
# Target: _ca-resolve-sha/scripts/resolve-sha.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# Script under test; executed with bash (not Included) by _mainf_run
_MAINF_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/resolve-sha.sh"

# --- ヘルパー ---
# Real git repository fixtures (gf_setup / gf_cleanup / gf_linear_repo / ...)
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/scripts/__tests__/helpers/git-fixture.sh"

# --- 内部ヘルパー ---
# 定数

# Tag ref pushed in T-RS-MAINF-10 / T-RS-MAINF-14 (a push that is not a branch push)
_MAINF_TAG_REF="refs/tags/v1.0.0"

# commit-count carrying an LF and a workflow command, used in T-RS-MAINF-15 (error stays 1 line)
_MAINF_LF_COUNT=$'1\n::add-mask::x'

# git's empty tree OID, expected as before_sha in T-RS-MAINF-16 (history shorter than commit-count)
_MAINF_EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

# Return code of _mainf_run_traced when the fixture builder fails (T-RS-MAINF-18 / T-RS-MAINF-19)
_MAINF_SETUP_FAILED=98

# Host-like global git config that marks a remote as a promisor, used in T-RS-MAINF-20
# (would make is_partial_clone report a partial clone if it reached the script)
_MAINF_POLLUTED_GITCONFIG=$'[remote "upstream"]\n\tpromisor = true\n'

# Regular file placed at the fixture repository path (main) inside the temporary
# root _mainf_setup creates, so its fixture build fails; used in T-RS-MAINF-24
_MAINF_BLOCKER="main"

# 関数

##
# Prepare the per-example environment: a temporary root (gf_setup), a 5-commit
# linear repository on main, an empty step output file, and the GitHub Actions
# variables every case shares. Variables a case sets itself are unset first,
# so values from a host CI runner never leak into the script.
# Sets: _MAINF_REPO — the repository path; _MAINF_OUTPUT — the output file path.
# Exports: GITHUB_OUTPUT, GITHUB_REF=refs/heads/main, GITHUB_EVENT_DELETED=false.
# ShellSpec skips every AfterEach (gf_cleanup) when a BeforeEach fails, so a
# fixture step that fails after gf_setup removes the temporary root here.
# @return 0 on success, 1 when any fixture step fails
_mainf_setup() {
  gf_setup || return 1
  _MAINF_REPO=$(gf_linear_repo main 5) || {
    gf_cleanup
    return 1
  }
  _MAINF_OUTPUT="${GF_TMP_ROOT}/github-output"
  : >"$_MAINF_OUTPUT" || {
    gf_cleanup
    return 1
  }
  export GITHUB_OUTPUT="$_MAINF_OUTPUT"
  export GITHUB_REF=refs/heads/main
  export GITHUB_EVENT_DELETED=false
  unset INPUT_COMMIT_COUNT INPUT_BEFORE_SHA INPUT_AFTER_SHA GITHUB_EVENT_NAME \
    GITHUB_BEFORE_SHA GITHUB_AFTER_SHA GITHUB_BASE_SHA GITHUB_HEAD_SHA
}

##
# Resolve a revision of the fixture repository to its full commit OID.
# Requires: _mainf_setup has been called (BeforeEach).
# @arg $1 rev — revision expression (e.g. HEAD, HEAD~1)
# @stdout the commit OID
# @return git rev-parse's exit code
_mainf_rev() {
  gf_git "$_MAINF_REPO" rev-parse "$1"
}

##
# Run resolve-sha.sh with the fixture repository as the working directory.
# The script runs with GIT_CONFIG_GLOBAL=/dev/null and GIT_CONFIG_NOSYSTEM=1
# (same isolation as the unit wrappers), so the host's global / system git
# config (e.g. a remote with promisor = true) never changes its git queries.
# The prefix must be at this call site: gf_setup unsets exported GIT_*
# variables, so isolation cannot be exported once in BeforeEach.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output
# @return the script's exit code, 1 when cd fails
_mainf_run() {
  (
    cd "$_MAINF_REPO" || exit 1
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 bash "$_MAINF_SCRIPT"
  )
}

##
# Build a --filter=blob:none partial clone of a 3-commit origin, then add one
# more commit to the origin only. That commit is a valid-format OID that exists
# in the promisor remote but not in the clone, so any object access to it from
# the clone would lazy-fetch it. Its absence is confirmed by listing the
# clone's local objects (cat-file --batch-all-objects never lazy-fetches).
# Requires: _mainf_setup has been called (BeforeEach).
# Sets: _MAINF_REPO — the partial clone path;
#       _MAINF_MISSING_OID — the origin-only commit OID;
#       _MAINF_PARTIAL_HEAD — HEAD of the partial clone (a local commit).
# @return 0 on success, 1 when any fixture step fails or the OID is present locally
_mainf_build_partial_missing() {
  local _mainf_origin _mainf_objects

  _mainf_origin="$(gf_linear_repo origin 3)" || return 1
  _MAINF_REPO="$(gf_partial_clone "$_mainf_origin" partial)" || return 1
  _MAINF_MISSING_OID="$(gf_commit "$_mainf_origin" after-clone)" || return 1
  _MAINF_PARTIAL_HEAD="$(gf_git "$_MAINF_REPO" rev-parse HEAD)" || return 1
  # stderr dropped: git warns "uses promisor remotes" here, which would leak into
  # the stderr under test (the exit code is still checked)
  _mainf_objects="$(gf_git "$_MAINF_REPO" cat-file --batch-all-objects --batch-check='%(objectname)' 2>/dev/null)" || return 1
  [[ $'\n'"$_mainf_objects"$'\n' != *$'\n'"$_MAINF_MISSING_OID"$'\n'* ]]
}

##
# Fixture builder for T-RS-MAINF-18: a pull_request whose base is the
# origin-only commit (see _mainf_build_partial_missing) and whose head is the
# clone's HEAD.
# Exports: GITHUB_EVENT_NAME=pull_request, GITHUB_BASE_SHA, GITHUB_HEAD_SHA.
# @return 0 on success, 1 when the fixture build fails
_mainf_build_partial_pr() {
  _mainf_build_partial_missing || return 1
  export GITHUB_EVENT_NAME=pull_request
  export GITHUB_BASE_SHA="$_MAINF_MISSING_OID"
  export GITHUB_HEAD_SHA="$_MAINF_PARTIAL_HEAD"
}

##
# Fixture builder for T-RS-MAINF-19: a before-sha / after-sha override whose
# before is the origin-only commit (see _mainf_build_partial_missing) and whose
# after is the clone's HEAD.
# Exports: GITHUB_EVENT_NAME=workflow_dispatch, INPUT_BEFORE_SHA, INPUT_AFTER_SHA.
# @return 0 on success, 1 when the fixture build fails
_mainf_build_partial_override() {
  _mainf_build_partial_missing || return 1
  export GITHUB_EVENT_NAME=workflow_dispatch
  export INPUT_BEFORE_SHA="$_MAINF_MISSING_OID"
  export INPUT_AFTER_SHA="$_MAINF_PARTIAL_HEAD"
}

##
# Run a fixture builder, then run resolve-sha.sh (_mainf_run) with GIT_TRACE
# pointing at a fresh trace file, so the trace holds only the script's git
# calls (the builder's clone / fetch are not traced).
# Requires: _mainf_setup has been called (BeforeEach).
# Sets: _MAINF_TRACE — the trace file path.
# @arg $1 builder — fixture builder function (e.g. _mainf_build_partial_pr)
# @stdout / @stderr the script's output
# @return the script's exit code, or _MAINF_SETUP_FAILED (98) when the builder fails
_mainf_run_traced() {
  "$1" || return "$_MAINF_SETUP_FAILED"
  _MAINF_TRACE="${GF_TMP_ROOT}/git-trace-run.log"
  GIT_TRACE="$_MAINF_TRACE" _mainf_run
}

##
# Simulate a developer's polluted global git config without touching the real
# one: write _MAINF_POLLUTED_GITCONFIG to a file under GF_TMP_ROOT and export
# GIT_CONFIG_GLOBAL pointing at it. Must run after gf_setup (BeforeEach), which
# unsets exported GIT_* variables. Used in T-RS-MAINF-20.
# Requires: _mainf_setup has been called (BeforeEach).
# Exports: GIT_CONFIG_GLOBAL — the polluted config file path.
# @return 0 on success, 1 when the file cannot be written
_mainf_pollute_global_config() {
  local _mainf_config="${GF_TMP_ROOT}/polluted.gitconfig"

  printf '%s' "$_MAINF_POLLUTED_GITCONFIG" >"$_mainf_config" || return 1
  export GIT_CONFIG_GLOBAL="$_mainf_config"
}

##
# Copy resolve-sha.sh, its library and the shared libraries into the fixture
# repository's working tree, keeping the action layout
# (.github/actions/_ca-resolve-sha/scripts and .github/actions/_libs), so the
# script can run with a scripts directory that is inside a git repository.
# The copies are untracked files; they do not change HEAD or its history.
# Used in T-RS-MAINF-21.
# Requires: _mainf_setup has been called (BeforeEach).
# Sets: _MAINF_COPY_DIR — the copied scripts directory.
# @return 0 on success, 1 when any copy step fails
_mainf_install_action_copy() {
  local _mainf_src_scripts _mainf_actions

  _mainf_src_scripts="$(dirname "$_MAINF_SCRIPT")" || return 1
  _mainf_actions="${_MAINF_REPO}/.github/actions"
  _MAINF_COPY_DIR="${_mainf_actions}/_ca-resolve-sha/scripts"
  mkdir -p "${_MAINF_COPY_DIR}/_libs" "${_mainf_actions}/_libs" || return 1
  cp "$_MAINF_SCRIPT" "${_MAINF_COPY_DIR}/" || return 1
  cp "${_mainf_src_scripts}/_libs/resolve-sha.lib.sh" "${_MAINF_COPY_DIR}/_libs/" || return 1
  cp "${_mainf_src_scripts}/../../_libs/"*.lib.sh "${_mainf_actions}/_libs/"
}

##
# Run resolve-sha.sh as `bash resolve-sha.sh` (a path without a slash) with the
# copied scripts directory (_mainf_install_action_copy) as the working
# directory, which is inside the fixture repository. Same git config isolation
# as _mainf_run. Used in T-RS-MAINF-21.
# Requires: _mainf_install_action_copy has been called.
# @stdout / @stderr the script's output
# @return the script's exit code, 1 when cd fails
_mainf_run_no_slash() {
  (
    cd "$_MAINF_COPY_DIR" || exit 1
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 bash resolve-sha.sh
  )
}

##
# Run resolve-sha.sh as `bash resolve-sha.sh` with the fixture repository as the
# working directory, so bash finds the script through PATH (the scripts
# directory is prepended). Same git config isolation as _mainf_run.
# Used in T-RS-MAINF-22.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output
# @return the script's exit code, 1 when cd fails
_mainf_run_via_path() {
  local _mainf_scripts_dir

  _mainf_scripts_dir="$(dirname "$_MAINF_SCRIPT")" || return 1
  (
    cd "$_MAINF_REPO" || exit 1
    PATH="${_mainf_scripts_dir}:${PATH}" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 bash resolve-sha.sh
  )
}

##
# Source resolve-sha.sh in a subshell whose working directory is the fixture
# repository, then return; main must not run, so nothing is written to the
# output file. Same git config isolation as _mainf_run. Used in T-RS-MAINF-23.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr anything printed while sourcing
# @return 0 when sourcing succeeds, non-zero otherwise
_mainf_source() {
  (
    cd "$_MAINF_REPO" || exit 1
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    # shellcheck source=.github/actions/_ca-resolve-sha/scripts/resolve-sha.sh
    # shellcheck disable=SC1091
    . "$_MAINF_SCRIPT"
  )
}

##
# Run _mainf_setup in a subshell with its fixture build forced to fail, and
# report whether the temporary root it created survives the failure. ShellSpec
# skips every AfterEach when a BeforeEach fails, so the hook must clean up its
# own root. mktemp is stubbed to record the root it creates (in the caller's
# GF_TMP_ROOT) and to place a regular file at _MAINF_BLOCKER in it, so
# gf_linear_repo cannot create the repository. A root that survives is removed
# here, so the probe never leaks it either. Used in T-RS-MAINF-24.
# Requires: _mainf_setup has been called (BeforeEach; the record file lives in
#           that example's GF_TMP_ROOT).
# @stdout "rc=<hook status> leaked=<yes|no|unknown>" (unknown: no root recorded)
# @return 0
_mainf_probe_setup_leak() {
  local _probe_record="${GF_TMP_ROOT}/probe-root"
  (
    mktemp() {
      local _probe_root
      _probe_root="$(command mktemp "$@")" || return 1
      printf '%s\n' "$_probe_root" >"$_probe_record" || return 1
      : >"${_probe_root}/${_MAINF_BLOCKER}" || return 1
      printf '%s\n' "$_probe_root"
    }
    _mainf_setup 2>/dev/null
    _probe_rc=$?
    _probe_root="$(cat "$_probe_record" 2>/dev/null)"
    if [[ -z "$_probe_root" ]]; then
      _probe_leaked=unknown
    elif [[ -e "$_probe_root" ]]; then
      _probe_leaked=yes
      rm -rf "$_probe_root"
    else
      _probe_leaked=no
    fi
    printf 'rc=%s leaked=%s\n' "$_probe_rc" "$_probe_leaked"
  )
}

# --- テスト本体 ---

##
# resolve-sha.sh: entry point of the _ca-resolve-sha composite action; reads the
# environment and writes before_sha / after_sha / resolution to GITHUB_OUTPUT.
# Assigned test IDs: T-RS-MAINF-01 .. T-RS-MAINF-24
Describe 'resolve-sha.sh'
  BeforeEach '_mainf_setup'
  AfterEach 'gf_cleanup'

  ##
  # main: run normalize_commit_count -> validate_override -> resolve_sha ->
  # emit_outputs in this order with the values read from the environment.
  # Scenarios: workflow_dispatch without commit-count resolves HEAD~1..HEAD
  #            (fallback-head-n); push resolves the event payload range
  #            (event); pull_request resolves base..head (event);
  #            before-sha / after-sha inputs take precedence (override);
  #            an invalid commit-count fails before resolution and writes
  #            nothing to the output file; with several invalid inputs at
  #            once only the first stage (commit-count) reports an error;
  #            an empty event name fails resolution and writes nothing to
  #            the output file; an unset event name fails the same way
  #            without tripping set -u; a partial clone fails without
  #            running git fetch and writes nothing to the output file; a
  #            tag push fails resolution on GITHUB_REF and writes nothing
  #            to the output file; an unset GITHUB_OUTPUT fails when the
  #            outputs are emitted instead of being silently discarded; an
  #            unwritable GITHUB_OUTPUT (a directory) fails the same way; a
  #            valid override still fails when the event name is empty; a
  #            valid override resolves even on a tag push (override); a
  #            commit-count containing an LF still yields a single
  #            escaped (%0A) error line; a history shorter than
  #            commit-count resolves from the empty tree (empty-tree); an
  #            output file that already has content keeps it (append); a
  #            partial clone fails with the partial clone error and without
  #            running git fetch even when a pull_request base or an
  #            override before-sha is a commit missing locally but present
  #            in the promisor remote; a host global git config that marks a
  #            remote as a promisor does not reach the script, so a normal
  #            repository still resolves; the script resolves when run
  #            as `bash resolve-sha.sh` from its own directory (no slash)
  #            and when bash finds it through PATH; sourcing it does not
  #            run main.
  Describe 'main'
    # Cases where the range is resolved and written to the output file
    Context 'When: 正常系'
      It '[Normal] T-RS-MAINF-01: workflow_dispatch で commit-count 未設定なら HEAD~1'
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~1)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=fallback-head-n"
      End

      It '[Normal] T-RS-MAINF-02: push の通常解決'
        export GITHUB_EVENT_NAME=push
        GITHUB_BEFORE_SHA=$(_mainf_rev HEAD~2)
        GITHUB_AFTER_SHA=$(_mainf_rev HEAD)
        export GITHUB_BEFORE_SHA GITHUB_AFTER_SHA
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~2)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=event"
      End

      It '[Normal] T-RS-MAINF-03: pull_request'
        export GITHUB_EVENT_NAME=pull_request
        GITHUB_BASE_SHA=$(_mainf_rev HEAD~3)
        GITHUB_HEAD_SHA=$(_mainf_rev HEAD)
        export GITHUB_BASE_SHA GITHUB_HEAD_SHA
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~3)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=event"
      End

      It '[Normal] T-RS-MAINF-04: オーバーライド'
        export GITHUB_EVENT_NAME=workflow_dispatch
        INPUT_BEFORE_SHA=$(_mainf_rev HEAD~2)
        INPUT_AFTER_SHA=$(_mainf_rev HEAD)
        export INPUT_BEFORE_SHA INPUT_AFTER_SHA
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~2)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=override"
      End

      It '[Normal] T-RS-MAINF-20: 開発者のグローバル git 設定に promisor があっても解決する'
        _mainf_pollute_global_config || return 1
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_run
        The status should equal 0
        The stderr should equal ""
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~1)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=fallback-head-n"
      End
    End

    # Cases where a stage rejects the input and nothing is written to the output file
    Context 'When: 異常系'
      It '[Error] T-RS-MAINF-05: 不正な commit-count'
        export GITHUB_EVENT_NAME=push
        export INPUT_COMMIT_COUNT=0
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::commit-count:"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-06: 3 つの不正が同時にあれば commit-count のエラーだけを出す'
        export GITHUB_EVENT_NAME=""
        export INPUT_COMMIT_COUNT=0
        INPUT_BEFORE_SHA=$(_mainf_rev HEAD~1)
        export INPUT_BEFORE_SHA
        When call _mainf_run
        The status should be failure
        The lines of stderr should equal 1
        The stderr should start with "::error::commit-count:"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-07: イベント名が空'
        export GITHUB_EVENT_NAME=""
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::GITHUB_EVENT_NAME:"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-08: イベント名が未設定'
        unset GITHUB_EVENT_NAME
        When call _mainf_run
        The status should be failure
        The stderr should not include "unbound variable"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-09: partial clone ではエラーにし、git fetch を起動しない'
        _mainf_origin="$(gf_linear_repo origin 5)" || return 1
        _MAINF_REPO="$(gf_partial_clone "$_mainf_origin" partial)" || return 1
        export GITHUB_EVENT_NAME=workflow_dispatch
        export GIT_TRACE="${GF_TMP_ROOT}/git-trace.log"
        When call _mainf_run
        The status should be failure
        The stderr should equal "::error::repository: partial clone is not supported (got: '${_MAINF_REPO}')"
        The file "$GIT_TRACE" should not be empty file
        The contents of file "$GIT_TRACE" should not include "fetch"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-10: タグの push'
        export GITHUB_EVENT_NAME=push
        export GITHUB_REF="$_MAINF_TAG_REF"
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::GITHUB_REF:"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-11: GITHUB_OUTPUT が未設定'
        export GITHUB_EVENT_NAME=workflow_dispatch
        unset GITHUB_OUTPUT
        When call _mainf_run
        The status should be failure
        The stderr should equal "::error::GITHUB_OUTPUT: value must not be empty"
      End

      It '[Error] T-RS-MAINF-12: GITHUB_OUTPUT が書き込めない'
        export GITHUB_EVENT_NAME=workflow_dispatch
        export GITHUB_OUTPUT="${GF_TMP_ROOT}/out-dir"
        mkdir "$GITHUB_OUTPUT"
        When call _mainf_run
        The status should be failure
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '${GITHUB_OUTPUT}')"
      End

      It '[Error] T-RS-MAINF-18: partial clone で base がローカルに無い pull_request でも git fetch を起動しない'
        When call _mainf_run_traced _mainf_build_partial_pr
        The status should equal 1
        The stderr should equal "::error::repository: partial clone is not supported (got: '${_MAINF_REPO}')"
        The file "$_MAINF_TRACE" should not be empty file
        The contents of file "$_MAINF_TRACE" should not include "fetch"
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-RS-MAINF-19: partial clone で before-sha がローカルに無いオーバーライドでも git fetch を起動しない'
        When call _mainf_run_traced _mainf_build_partial_override
        The status should equal 1
        The stderr should equal "::error::repository: partial clone is not supported (got: '${_MAINF_REPO}')"
        The file "$_MAINF_TRACE" should not be empty file
        The contents of file "$_MAINF_TRACE" should not include "fetch"
        The file "$_MAINF_OUTPUT" should be empty file
      End
    End

    # Boundary cases where a valid input does not mask another stage's error
    Context 'When: エッジケース'
      It '[Edge] T-RS-MAINF-13: 有効なオーバーライドでもイベント名が空ならエラー'
        export GITHUB_EVENT_NAME=""
        INPUT_BEFORE_SHA=$(_mainf_rev HEAD~1)
        INPUT_AFTER_SHA=$(_mainf_rev HEAD)
        export INPUT_BEFORE_SHA INPUT_AFTER_SHA
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::GITHUB_EVENT_NAME:"
      End

      It '[Edge] T-RS-MAINF-14: 有効なオーバーライドならタグの push でも解決する'
        export GITHUB_EVENT_NAME=push
        export GITHUB_REF="$_MAINF_TAG_REF"
        INPUT_BEFORE_SHA=$(_mainf_rev HEAD~1)
        INPUT_AFTER_SHA=$(_mainf_rev HEAD)
        export INPUT_BEFORE_SHA INPUT_AFTER_SHA
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~1)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=override"
      End

      It '[Edge] T-RS-MAINF-15: commit-count に LF が含まれてもエラーは 1 行'
        export GITHUB_EVENT_NAME=workflow_dispatch
        export INPUT_COMMIT_COUNT="$_MAINF_LF_COUNT"
        When call _mainf_run
        The status should be failure
        The lines of stderr should equal 1
        The stderr should include "%0A"
      End

      It '[Edge] T-RS-MAINF-16: 履歴不足では empty-tree で成功する'
        _MAINF_REPO=$(gf_linear_repo short 2)
        export GITHUB_EVENT_NAME=workflow_dispatch
        export INPUT_COMMIT_COUNT=1000
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$_MAINF_EMPTY_TREE"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=empty-tree"
      End

      It '[Edge] T-RS-MAINF-17: 既存の出力ファイルの内容を残す'
        printf 'existing=1\n' >"$_MAINF_OUTPUT"
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_run
        The status should equal 0
        The line 1 of contents of file "$_MAINF_OUTPUT" should equal "existing=1"
      End

      It '[Edge] T-RS-MAINF-21: scripts ディレクトリで bash resolve-sha.sh (スラッシュなし) でも解決する'
        _mainf_install_action_copy || return 1
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_run_no_slash
        The status should equal 0
        The stderr should equal ""
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~1)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=fallback-head-n"
      End

      It '[Edge] T-RS-MAINF-22: PATH 経由で見つけた resolve-sha.sh でも main を実行する'
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_run_via_path
        The status should equal 0
        The stderr should equal ""
        The contents of file "$_MAINF_OUTPUT" should include "before_sha=$(_mainf_rev HEAD~1)"
        The contents of file "$_MAINF_OUTPUT" should include "after_sha=$(_mainf_rev HEAD)"
        The contents of file "$_MAINF_OUTPUT" should include "resolution=fallback-head-n"
      End

      It '[Edge] T-RS-MAINF-23: source しただけでは main を実行しない'
        export GITHUB_EVENT_NAME=workflow_dispatch
        When call _mainf_source
        The status should equal 0
        The stderr should equal ""
        The file "$_MAINF_OUTPUT" should be empty file
      End
    End
  End

  ##
  # _mainf_setup: the BeforeEach of this suite. ShellSpec skips every AfterEach
  # (gf_cleanup) when a BeforeEach fails, so the hook removes the temporary root
  # it created itself when a later fixture step fails.
  # Scenarios: a failing fixture build makes the hook fail and leaves no
  #            temporary root behind.
  Describe '_mainf_setup'
    # 異常系: the fixture build fails after gf_setup
    Context 'When: 異常系'
      It '[Error] T-RS-MAINF-24: フィクスチャ作成に失敗すると、作った一時ルートを削除して失敗する'
        When call _mainf_probe_setup_leak
        The status should equal 0
        The output should equal "rc=1 leaked=no"
      End
    End
  End
End
