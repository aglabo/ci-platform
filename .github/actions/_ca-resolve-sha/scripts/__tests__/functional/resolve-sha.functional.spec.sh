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

# 関数

##
# Prepare the per-example environment: a temporary root (gf_setup), a 5-commit
# linear repository on main, an empty step output file, and the GitHub Actions
# variables every case shares. Variables a case sets itself are unset first,
# so values from a host CI runner never leak into the script.
# Sets: _MAINF_REPO — the repository path; _MAINF_OUTPUT — the output file path.
# Exports: GITHUB_OUTPUT, GITHUB_REF=refs/heads/main, GITHUB_EVENT_DELETED=false.
# @return 0 on success, 1 when any fixture step fails
_mainf_setup() {
  gf_setup || return 1
  _MAINF_REPO=$(gf_linear_repo main 5) || return 1
  _MAINF_OUTPUT="${GF_TMP_ROOT}/github-output"
  : >"$_MAINF_OUTPUT" || return 1
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
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout / @stderr the script's output
# @return the script's exit code, 1 when cd fails
_mainf_run() {
  (
    cd "$_MAINF_REPO" || exit 1
    bash "$_MAINF_SCRIPT"
  )
}

# --- テスト本体 ---

##
# resolve-sha.sh: entry point of the _ca-resolve-sha composite action; reads the
# environment and writes before_sha / after_sha / resolution to GITHUB_OUTPUT.
# Assigned test IDs: T-RS-MAINF-01 .. T-RS-MAINF-17
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
  #            output file that already has content keeps it (append).
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
        The contents of file "$_MAINF_OUTPUT" should include "resolution=event"
      End

      It '[Normal] T-RS-MAINF-04: オーバーライド'
        export GITHUB_EVENT_NAME=workflow_dispatch
        INPUT_BEFORE_SHA=$(_mainf_rev HEAD~2)
        INPUT_AFTER_SHA=$(_mainf_rev HEAD)
        export INPUT_BEFORE_SHA INPUT_AFTER_SHA
        When call _mainf_run
        The status should equal 0
        The contents of file "$_MAINF_OUTPUT" should include "resolution=override"
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
        _MAINF_REPO=$(gf_partial_clone "$(gf_linear_repo origin 5)" partial)
        export GITHUB_EVENT_NAME=workflow_dispatch
        export GIT_TRACE="${GF_TMP_ROOT}/git-trace.log"
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::repository:"
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
        The stderr should start with "::error::GITHUB_OUTPUT:"
      End

      It '[Error] T-RS-MAINF-12: GITHUB_OUTPUT が書き込めない'
        export GITHUB_EVENT_NAME=workflow_dispatch
        export GITHUB_OUTPUT="${GF_TMP_ROOT}/out-dir"
        mkdir "$GITHUB_OUTPUT"
        When call _mainf_run
        The status should be failure
        The stderr should start with "::error::GITHUB_OUTPUT:"
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
    End
  End
End
