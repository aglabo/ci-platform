#!/usr/bin/env bash
# src: .github/actions/_libs/__tests__/unit/gha-error.unit.spec.sh
# @(#) : unit tests for error.lib.sh (gha_error and load guard)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

# Test suite for error.lib.sh
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: _libs/error.lib.sh
# Guard:  ERROR_LIB_LOADED

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# gha_error tests (T-GCF-GE-*) call the function loaded by Include.
# Load guard tests (T-GCF-ELG-*) source the library inside a fresh bash process
# (see _source_lib_in_fresh_shell) so that guard state does not leak between examples.
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/error.lib.sh"
LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/error.lib.sh"

# --- 内部ヘルパー ---
# 定数
# Value carrying an LF followed by a workflow command; used by T-GCF-GE-05
_GE_INJECTED_VALUE=$'x\n::add-mask::secret'
# Value with a CR between two characters; used by T-GCF-GE-08
_GE_CR_VALUE=$'a\rb'
# Value with an LF between two characters; used by T-GCF-GE-09
_GE_LF_VALUE=$'a\nb'

# 関数

##
# @description Source error.lib.sh in a fresh bash process and print the observable state.
#              The guard variable is unset before sourcing; if $1 is given, it is preset to that value.
# @arg $1 preset — optional value assigned to ERROR_LIB_LOADED before sourcing
# @stdout one per line:
#         "loaded=<ERROR_LIB_LOADED>",
#         "gha_error=<defined|undefined>",
#         "GHA_TARGET_GITHUB_OUTPUT=<value|undefined>",
#         "GHA_MSG_NOT_WRITABLE=<value|undefined>",
#         "GHA_MSG_WRITE_FAILED=<value|undefined>",
#         "source_status=<exit status of the source>"
# @return exit status of the fresh bash process
_source_lib_in_fresh_shell() {
  bash -c '
    unset ERROR_LIB_LOADED
    [ "$#" -ge 2 ] && ERROR_LIB_LOADED="$2"
    . "$1"
    _source_status=$?
    echo "loaded=${ERROR_LIB_LOADED:-}"
    if declare -F gha_error >/dev/null; then
      echo "gha_error=defined"
    else
      echo "gha_error=undefined"
    fi
    for _var in GHA_TARGET_GITHUB_OUTPUT GHA_MSG_NOT_WRITABLE GHA_MSG_WRITE_FAILED; do
      echo "${_var}=${!_var-undefined}"
    done
    echo "source_status=${_source_status}"
  ' _ "$LIB_PATH" "$@"
}

##
# @description Source error.lib.sh twice in a fresh bash process (guard variable unset beforehand).
#              Used to verify that re-sourcing an already-loaded library is harmless
#              (the readonly constants are not redefined).
# @stdout (none)
# @stderr whatever either source writes to stderr
# @return exit status of the second source
_resource_lib_in_fresh_shell() {
  bash -c '
    unset ERROR_LIB_LOADED
    . "$1"
    . "$1"
  ' _ "$LIB_PATH"
}

##
# @description Source error.lib.sh in a fresh bash process (guard variable unset beforehand)
#              and run the given shell snippet there, so that it can refer to the constants.
# @arg $1 snippet — shell code evaluated after the source (e.g. 'gha_error "$GHA_TARGET_GITHUB_OUTPUT" ...')
# @stdout whatever the snippet writes to stdout
# @stderr whatever the snippet writes to stderr
# @return exit status of the snippet
_call_in_fresh_shell() {
  bash -c '
    unset ERROR_LIB_LOADED
    . "$1"
    eval "$2"
  ' _ "$LIB_PATH" "$1"
}

##
# @description Source error.lib.sh in a fresh bash process (guard variable unset beforehand)
#              and print whether each constant carries the readonly attribute.
# @stdout one per line, in this order:
#         "GHA_TARGET_GITHUB_OUTPUT=<readonly|writable|undefined>",
#         "GHA_MSG_NOT_WRITABLE=<readonly|writable|undefined>",
#         "GHA_MSG_WRITE_FAILED=<readonly|writable|undefined>"
# @return exit status of the fresh bash process
_constant_attrs_in_fresh_shell() {
  bash -c '
    unset ERROR_LIB_LOADED
    . "$1"
    for _var in GHA_TARGET_GITHUB_OUTPUT GHA_MSG_NOT_WRITABLE GHA_MSG_WRITE_FAILED; do
      if ! _decl=$(declare -p "$_var" 2>/dev/null); then
        echo "${_var}=undefined"
        continue
      fi
      # attribute word only ("declare -r NAME=..." -> "r"); the value may contain "r"
      _attrs="${_decl#declare -}"
      _attrs="${_attrs%% *}"
      if [[ "$_attrs" == *r* ]]; then
        echo "${_var}=readonly"
      else
        echo "${_var}=writable"
      fi
    done
  ' _ "$LIB_PATH"
}

# --- テスト本体 ---

##
# error.lib.sh: shared error reporting helpers for composite actions.
Describe 'error.lib.sh'
  ##
  # gha_error: emit one "::error::" annotation line to stderr, in the normal form
  # "::error::<target>: <problem> (got: '<value>')" or, with fewer than 3 arguments,
  # the empty form "::error::<target>: value must not be empty".
  # Scenarios: the normal form is written to stderr only (stdout stays empty);
  #            an explicitly passed empty value still uses the normal form;
  #            fewer than 3 arguments use the empty form;
  #            a value carrying LF cannot inject a workflow command line;
  #            "%", CR and LF in the value become "%25", "%0D" and "%0A",
  #            with "%" encoded first; target and problem are printed as is.
  Describe 'gha_error'
    # 正常系: the normal form (3 arguments) and the empty form (target only)
    Context 'When: 正常系'
      It '[Normal] T-GCF-GE-01: 通常の形式で stderr に 1 行出す'
        When call gha_error commit-count invalid 0
        The status should equal 0
        The stderr should equal "::error::commit-count: invalid (got: '0')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-GCF-GE-02: 終了コード 0 で stdout には何も出さない'
        When call gha_error commit-count invalid 0
        The status should equal 0
        The stdout should equal ''
        The stderr should be present
      End

      It '[Normal] T-GCF-GE-03: 空文字列の値は通常の形式で出す'
        When call gha_error after-sha "one side only" ""
        The status should equal 0
        The stderr should equal "::error::after-sha: one side only (got: '')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-GCF-GE-04: 引数が target だけなら空の形式で出す'
        When call gha_error GITHUB_EVENT_NAME
        The status should equal 0
        The stderr should equal "::error::GITHUB_EVENT_NAME: value must not be empty"
        The lines of stderr should equal 1
      End
    End

    # 異常系: values that try to inject a workflow command into the log
    Context 'When: 異常系'
      It '[Error] T-GCF-GE-05: LF とコマンドを含む値を 1 行に収める'
        When call gha_error before-sha bad "$_GE_INJECTED_VALUE"
        The status should equal 0
        The lines of stderr should equal 1
        The stderr should not include "${SHELLSPEC_LF}::add-mask::"
        The stderr should include "(got: 'x%0A::add-mask::secret')"
      End
    End

    # エッジケース: the argument-count boundary and how the value is encoded
    Context 'When: エッジケース'
      It '[Edge] T-GCF-GE-06: 引数が 2 個なら problem を使わず空の形式で出す'
        When call gha_error GITHUB_EVENT_NAME empty
        The status should equal 0
        The stderr should equal "::error::GITHUB_EVENT_NAME: value must not be empty"
        The lines of stderr should equal 1
      End

      It '[Edge] T-GCF-GE-07: % を %25 にする'
        When call gha_error t p "a%b"
        The stderr should include "(got: 'a%25b')"
      End

      It '[Edge] T-GCF-GE-08: CR を %0D にする'
        When call gha_error t p "$_GE_CR_VALUE"
        The stderr should include "(got: 'a%0Db')"
      End

      It '[Edge] T-GCF-GE-09: LF を %0A にする'
        When call gha_error t p "$_GE_LF_VALUE"
        The stderr should include "(got: 'a%0Ab')"
      End

      It '[Edge] T-GCF-GE-10: % を先に置き換える'
        When call gha_error t p "%0A"
        The stderr should include "(got: '%250A')"
      End

      It '[Edge] T-GCF-GE-11: target と problem はそのまま出す'
        When call gha_error "a%b" "p%s" v
        The status should equal 0
        The stderr should equal "::error::a%b: p%s (got: 'v')"
      End
    End
  End

  ##
  # load guard: ERROR_LIB_LOADED prevents the library body from being re-evaluated.
  # Scenarios: sourcing the library sets the guard and defines gha_error and the
  #            readonly constants; re-sourcing is harmless;
  #            gha_error works together with the constants after the source;
  #            a preset guard makes the source return early without defining anything,
  #            while an empty guard loads the library as usual.
  Describe 'load guard'
    # 正常系: the library is sourced with the guard variable unset
    Context 'When: 正常系'
      It '[Normal] T-GCF-ELG-01: 未設定で source すると ERROR_LIB_LOADED=1 になり gha_error が定義される'
        When call _source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'gha_error=defined'
        The line 6 of output should equal 'source_status=0'
      End

      It '[Normal] T-GCF-ELG-02: 3 つの定数が正しい値で定義される'
        When call _source_lib_in_fresh_shell
        The status should equal 0
        The line 3 of output should equal 'GHA_TARGET_GITHUB_OUTPUT=GITHUB_OUTPUT'
        The line 4 of output should equal 'GHA_MSG_NOT_WRITABLE=is not a writable file'
        The line 5 of output should equal 'GHA_MSG_WRITE_FAILED=failed to write'
      End

      It '[Normal] T-GCF-ELG-03: 3 つの定数が readonly で定義される'
        When call _constant_attrs_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'GHA_TARGET_GITHUB_OUTPUT=readonly'
        The line 2 of output should equal 'GHA_MSG_NOT_WRITABLE=readonly'
        The line 3 of output should equal 'GHA_MSG_WRITE_FAILED=readonly'
      End

      It '[Normal] T-GCF-ELG-04: source 済みの状態で再度 source しても終了コード 0 で stderr は空'
        When call _resource_lib_in_fresh_shell
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: gha_error reports a GITHUB_OUTPUT error built from the constants
    Context 'When: 異常系'
      It '[Error] T-GCF-ELG-05: source 後の gha_error は定数を使って GITHUB_OUTPUT のエラーを出す'
        When call _call_in_fresh_shell 'gha_error "$GHA_TARGET_GITHUB_OUTPUT" "$GHA_MSG_NOT_WRITABLE" /x'
        The status should equal 0
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '/x')"
      End
    End

    # エッジケース: the guard variable is already set before the library is sourced
    Context 'When: エッジケース'
      It '[Edge] T-GCF-ELG-06: ERROR_LIB_LOADED=1 設定済みで source すると終了コード 0 で何も定義せずに戻る'
        When call _source_lib_in_fresh_shell 1
        The status should equal 0
        The line 2 of output should equal 'gha_error=undefined'
        The line 3 of output should equal 'GHA_TARGET_GITHUB_OUTPUT=undefined'
        The line 4 of output should equal 'GHA_MSG_NOT_WRITABLE=undefined'
        The line 5 of output should equal 'GHA_MSG_WRITE_FAILED=undefined'
        The line 6 of output should equal 'source_status=0'
      End

      It '[Edge] T-GCF-ELG-07: ERROR_LIB_LOADED が空文字列なら通常どおり読み込む'
        When call _source_lib_in_fresh_shell ''
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'gha_error=defined'
        The line 3 of output should equal 'GHA_TARGET_GITHUB_OUTPUT=GITHUB_OUTPUT'
      End
    End
  End
End
