#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-config/scripts/__tests__/functional/resolve-config.functional.spec.sh
# @(#) : functional tests for resolve-config.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Functional test suite for resolve-config.sh
# Module: composite-action/resolve-config (test_scope RC)
# Target: _ca-resolve-config/scripts/resolve-config.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# Script under test; executed with bash (not Included) by _rcf_run
_RCF_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-config/scripts/resolve-config.sh"

# --- 内部ヘルパー ---

# Newline, for multi-line patterns
_RCF_NL=$'\n'

##
# Prepare the per-example environment: a temporary GITHUB_WORKSPACE with the
# config files the cases use, and an empty GITHUB_OUTPUT. INPUT_* variables
# are unset so values from a host CI runner never leak into the script.
# Sets: _RCF_TMP, _RCF_WS, _RCF_OUTPUT. Exports: GITHUB_WORKSPACE, GITHUB_OUTPUT.
# @return 0 on success, 1 when a fixture step fails
_rcf_setup() {
  _RCF_TMP="$(mktemp -d)" || return 1
  _RCF_WS="${_RCF_TMP}/ws"
  _RCF_OUTPUT="${_RCF_TMP}/github-output"
  mkdir -p "${_RCF_WS}/conf" || return 1
  : >"${_RCF_WS}/conf/a.yml" || return 1
  : >"${_RCF_WS}/l.yml" || return 1
  : >"${_RCF_WS}/g.yml" || return 1
  : >"$_RCF_OUTPUT" || return 1
  export GITHUB_WORKSPACE="$_RCF_WS"
  export GITHUB_OUTPUT="$_RCF_OUTPUT"
  unset INPUT_CONFIG INPUT_LOCAL_CONFIG INPUT_GLOBAL_CONFIG
}

##
# Remove the temporary directory and the exported variables.
# @return 0 always
_rcf_cleanup() {
  [[ -n ${_RCF_TMP:-} ]] && rm -rf "$_RCF_TMP"
  unset _RCF_TMP _RCF_WS _RCF_OUTPUT GITHUB_WORKSPACE GITHUB_OUTPUT \
    INPUT_CONFIG INPUT_LOCAL_CONFIG INPUT_GLOBAL_CONFIG
  return 0
}

##
# Run resolve-config.sh with the current environment.
# @stdout / @stderr the script's output
# @return the script's exit code
_rcf_run() {
  bash "$_RCF_SCRIPT"
}

##
# Print the contents of the step output file.
_rcf_output() {
  cat "$_RCF_OUTPUT"
}

# --- テスト本体 ---
# T-RC-01-01 .. T-RC-01-06 : [Normal]
# T-RC-02-01 .. T-RC-02-03 : [Error]
# T-RC-03-01               : [Edge]
# T-RC-04-01               : [Edge] no fallback
Describe 'resolve-config.sh'
  BeforeEach '_rcf_setup'
  AfterEach '_rcf_cleanup'

  Context 'When: 設定ファイルが解決できる'
    It '[Normal] T-RC-01-01: INPUT_CONFIG が存在すると source=input'
      export INPUT_CONFIG="conf/a.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should start with "::notice::"
      The contents of file "$_RCF_OUTPUT" should equal "config-file=${_RCF_WS}/conf/a.yml
source=input"
    End

    It '[Normal] T-RC-01-02: local のみ存在すると source=local'
      export INPUT_LOCAL_CONFIG="l.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should start with "::notice::"
      The contents of file "$_RCF_OUTPUT" should equal "config-file=${_RCF_WS}/l.yml
source=local"
    End

    It '[Normal] T-RC-01-03: global のみ存在すると source=global'
      export INPUT_GLOBAL_CONFIG="g.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should start with "::notice::"
      The contents of file "$_RCF_OUTPUT" should equal "config-file=${_RCF_WS}/g.yml
source=global"
    End

    It '[Normal] T-RC-01-04: local と global が両方存在すると local が優先'
      export INPUT_LOCAL_CONFIG="l.yml"
      export INPUT_GLOBAL_CONFIG="g.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should start with "::notice::"
      The contents of file "$_RCF_OUTPUT" should equal "config-file=${_RCF_WS}/l.yml
source=local"
    End

    It '[Normal] T-RC-01-05: ::notice:: 行に source と path が 1 行出る'
      export INPUT_CONFIG="conf/a.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should equal "::notice::Using input config: ${_RCF_WS}/conf/a.yml"
    End

    It '[Normal] T-RC-01-06: GITHUB_OUTPUT のキーは config-file と source のみ'
      export INPUT_CONFIG="conf/a.yml"
      When call _rcf_run
      The status should equal 0
      The stdout should start with "::notice::"
      The contents of file "$_RCF_OUTPUT" should match pattern "config-file=*${_RCF_NL}source=*"
    End
  End

  Context 'When: 解決できずエラーになる'
    It '[Error] T-RC-02-01: INPUT_CONFIG が存在しないとエラー'
      export INPUT_CONFIG="missing.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should start with "::error::"
      The contents of file "$_RCF_OUTPUT" should equal ""
    End

    It '[Error] T-RC-02-02: どの設定ファイルも存在しないとエラー'
      When call _rcf_run
      The status should not equal 0
      The stderr should start with "::error::"
      The contents of file "$_RCF_OUTPUT" should equal ""
    End

    It "[Error] T-RC-02-03: '..' を含むパスを拒否する"
      export INPUT_CONFIG="../outside.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should include "must not contain"
      The contents of file "$_RCF_OUTPUT" should equal ""
    End
  End

  Context 'When: source で読み込む'
    It '[Edge] T-RC-03-01: source しても main が走らない'
      export INPUT_CONFIG="conf/a.yml"
      # $1 is expanded by the inner bash (the script path), not by this shell
      # shellcheck disable=SC2016
      When call bash -c 'source "$1"; echo done' _ "$_RCF_SCRIPT"
      The status should equal 0
      The stdout should equal "done"
      The contents of file "$_RCF_OUTPUT" should equal ""
    End
  End

  Context 'When: INPUT_CONFIG が不在で local は存在する'
    It '[Edge] T-RC-04-01: local にフォールバックせずエラー'
      export INPUT_CONFIG="missing.yml"
      export INPUT_LOCAL_CONFIG="l.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should start with "::error::"
      The contents of file "$_RCF_OUTPUT" should equal ""
    End
  End

  Context 'When: パスに空白を含む'
    It '[Error] T-RC-05-01: INPUT_CONFIG に空白があると拒否する'
      mkdir -p "${_RCF_WS}/conf dir" && : >"${_RCF_WS}/conf dir/a b.yml"
      export INPUT_CONFIG="conf dir/a b.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should match pattern "::error::*"
      The lines of stderr should equal 1
      The contents of file "$_RCF_OUTPUT" should equal ""
    End

    It '[Error] T-RC-05-02: INPUT_LOCAL_CONFIG に空白があると拒否する'
      : >"${_RCF_WS}/l c.yml"
      export INPUT_LOCAL_CONFIG="l c.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should match pattern "::error::*"
      The lines of stderr should equal 1
      The contents of file "$_RCF_OUTPUT" should equal ""
    End

    It '[Error] T-RC-05-03: INPUT_GLOBAL_CONFIG に空白があると拒否する'
      : >"${_RCF_WS}/g c.yml"
      export INPUT_GLOBAL_CONFIG="g c.yml"
      When call _rcf_run
      The status should not equal 0
      The stderr should match pattern "::error::*"
      The lines of stderr should equal 1
      The contents of file "$_RCF_OUTPUT" should equal ""
    End
  End
End
