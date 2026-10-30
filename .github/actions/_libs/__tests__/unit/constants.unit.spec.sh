#!/usr/bin/env bash
# src: .github/actions/_libs/__tests__/unit/constants.unit.spec.sh
# @(#) : unit tests for constants.lib.sh (shared limits and load guard)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

# Test suite for constants.lib.sh
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: _libs/constants.lib.sh
# Guard:  CONSTANTS_LIB_LOADED

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# The library is sourced inside a fresh bash process (see
# _clg_source_lib_in_fresh_shell) so that guard state does not leak between examples.
LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/constants.lib.sh"

# --- 内部ヘルパー ---
# 関数

##
# @description Source constants.lib.sh in a fresh bash process and print the observable state.
#              The guard variable is unset before sourcing; if $1 is given, it is preset to that value.
# @arg $1 preset — optional value assigned to CONSTANTS_LIB_LOADED before sourcing
# @stdout one per line:
#         "loaded=<CONSTANTS_LIB_LOADED>",
#         "GHA_MAX_ENV_VALUE_BYTES=<value|undefined>",
#         "GHA_MAX_PR_FILES=<value|undefined>",
#         "source_status=<exit status of the source>"
# @return exit status of the fresh bash process
_clg_source_lib_in_fresh_shell() {
  bash -c '
    unset CONSTANTS_LIB_LOADED
    [ "$#" -ge 2 ] && CONSTANTS_LIB_LOADED="$2"
    . "$1"
    _source_status=$?
    echo "loaded=${CONSTANTS_LIB_LOADED:-}"
    for _var in GHA_MAX_ENV_VALUE_BYTES GHA_MAX_PR_FILES; do
      echo "${_var}=${!_var-undefined}"
    done
    echo "source_status=${_source_status}"
  ' _ "$LIB_PATH" "$@"
}

##
# @description Source constants.lib.sh in a fresh bash process (guard variable unset beforehand)
#              and print whether each constant carries the readonly attribute.
# @stdout one per line, in this order:
#         "GHA_MAX_ENV_VALUE_BYTES=<readonly|writable|undefined>",
#         "GHA_MAX_PR_FILES=<readonly|writable|undefined>"
# @return exit status of the fresh bash process
_clg_constant_attrs_in_fresh_shell() {
  bash -c '
    unset CONSTANTS_LIB_LOADED
    . "$1"
    for _var in GHA_MAX_ENV_VALUE_BYTES GHA_MAX_PR_FILES; do
      if ! _decl=$(declare -p "$_var" 2>/dev/null); then
        echo "${_var}=undefined"
        continue
      fi
      # attribute word only ("declare -r NAME=..." -> "r")
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

##
# @description Source constants.lib.sh twice in a fresh bash process (guard variable unset beforehand).
#              Used to verify that re-sourcing an already-loaded library is harmless
#              (the readonly constants are not redefined).
# @stdout (none)
# @stderr whatever either source writes to stderr
# @return exit status of the second source
_clg_resource_lib_in_fresh_shell() {
  bash -c '
    unset CONSTANTS_LIB_LOADED
    . "$1"
    . "$1"
  ' _ "$LIB_PATH"
}

# --- テスト本体 ---

##
# constants.lib.sh: limits shared by the composite actions.
# Scenarios: sourcing the library sets the guard and defines the shared limits
#            GHA_MAX_ENV_VALUE_BYTES (120000) and GHA_MAX_PR_FILES (3000) as
#            readonly; re-sourcing is harmless; a preset guard makes the source
#            return early without defining anything, while an empty guard loads
#            the library as usual.
Describe 'constants.lib.sh'
  Describe 'T-GCF-CLG: load guard and constants'
    # 正常系: the library is sourced with the guard variable unset
    Context 'When: 正常系'
      It '[Normal] T-GCF-CLG-01: 未設定で source すると CONSTANTS_LIB_LOADED=1 になる'
        When call _clg_source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 4 of output should equal 'source_status=0'
      End

      It '[Normal] T-GCF-CLG-02: 2 つの定数が正しい値で定義される'
        When call _clg_source_lib_in_fresh_shell
        The status should equal 0
        The line 2 of output should equal 'GHA_MAX_ENV_VALUE_BYTES=120000'
        The line 3 of output should equal 'GHA_MAX_PR_FILES=3000'
      End

      It '[Normal] T-GCF-CLG-03: 2 つの定数が readonly で定義される'
        When call _clg_constant_attrs_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'GHA_MAX_ENV_VALUE_BYTES=readonly'
        The line 2 of output should equal 'GHA_MAX_PR_FILES=readonly'
      End

      It '[Normal] T-GCF-CLG-04: source 済みの状態で再度 source しても終了コード 0 で stderr は空'
        When call _clg_resource_lib_in_fresh_shell
        The status should equal 0
        The stderr should equal ''
      End
    End

    # エッジケース: the guard variable is already set before the library is sourced
    Context 'When: エッジケース'
      It '[Edge] T-GCF-CLG-05: CONSTANTS_LIB_LOADED=1 設定済みで source すると何も定義せずに戻る'
        When call _clg_source_lib_in_fresh_shell 1
        The status should equal 0
        The line 2 of output should equal 'GHA_MAX_ENV_VALUE_BYTES=undefined'
        The line 3 of output should equal 'GHA_MAX_PR_FILES=undefined'
        The line 4 of output should equal 'source_status=0'
      End

      It '[Edge] T-GCF-CLG-06: CONSTANTS_LIB_LOADED が空文字列なら通常どおり読み込む'
        When call _clg_source_lib_in_fresh_shell ''
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'GHA_MAX_ENV_VALUE_BYTES=120000'
      End
    End
  End
End
