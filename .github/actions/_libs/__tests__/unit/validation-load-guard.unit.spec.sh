#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

# Test suite for the load guard of validation.lib.sh
# Module: composite-action/resolve-sha (test_scope RS, target VLG)
# Target: _libs/validation.lib.sh
# Guard:  VALIDATION_LIB_LOADED

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# validation.lib.sh is sourced inside a fresh bash process (see _source_lib_in_fresh_shell),
# not via Include, so that guard state does not leak between examples.
LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"

# --- 内部ヘルパー ---
# 関数

##
# @description Source validation.lib.sh in a fresh bash process and print the observable state.
#              The guard variable is unset before sourcing; if $1 is given, it is preset to that value.
# @arg $1 preset — optional value assigned to VALIDATION_LIB_LOADED before sourcing
# @stdout one per line:
#         "loaded=<VALIDATION_LIB_LOADED>",
#         "validate_symbol=<defined|undefined>",
#         "validate_positive_int=<defined|undefined>",
#         "source_status=<exit status of the source>"
# @return exit status of the fresh bash process
_source_lib_in_fresh_shell() {
  bash -c '
    unset VALIDATION_LIB_LOADED
    [ "$#" -ge 2 ] && VALIDATION_LIB_LOADED="$2"
    . "$1"
    _source_status=$?
    echo "loaded=${VALIDATION_LIB_LOADED:-}"
    for _fn in validate_symbol validate_positive_int; do
      if declare -F "$_fn" >/dev/null; then
        echo "${_fn}=defined"
      else
        echo "${_fn}=undefined"
      fi
    done
    echo "source_status=${_source_status}"
  ' _ "$LIB_PATH" "$@"
}

##
# @description Source validation.lib.sh twice in a fresh bash process (guard variable unset beforehand).
#              Used to verify that re-sourcing an already-loaded library is harmless.
# @stdout (none)
# @stderr whatever either source writes to stderr
# @return exit status of the second source
_resource_lib_in_fresh_shell() {
  bash -c '
    unset VALIDATION_LIB_LOADED
    . "$1"
    . "$1"
  ' _ "$LIB_PATH"
}

##
# @description Source validation.lib.sh in a fresh bash process (guard variable unset beforehand)
#              and call validate_symbol with the given arguments.
# @arg $@ arguments passed to validate_symbol (value, field_name, pattern[, max_length])
# @stdout whatever validate_symbol writes to stdout
# @stderr whatever validate_symbol writes to stderr
# @return exit status of validate_symbol
_validate_symbol_in_fresh_shell() {
  bash -c '
    unset VALIDATION_LIB_LOADED
    . "$1"
    shift
    validate_symbol "$@"
  ' _ "$LIB_PATH" "$@"
}

# --- テスト本体 ---

##
# validation.lib.sh: shared validation helpers for composite actions.
# Assigned test IDs: T-RS-VLG-01 .. T-RS-VLG-04
Describe 'validation.lib.sh'
  ##
  # load guard: VALIDATION_LIB_LOADED prevents the library body from being re-evaluated.
  # Scenarios: sourcing the library sets the guard and defines the validation functions;
  #            the guard does not change the error output of existing validation functions;
#            a preset guard makes the source return early without defining functions.
  Describe 'load guard'
    # 正常系: the library is sourced with the guard variable unset
    Context 'When: 正常系'
      It '[Normal] T-RS-VLG-01: 未設定で source すると VALIDATION_LIB_LOADED=1 になり validate_symbol が定義される'
        When call _source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'validate_symbol=defined'
      End

      It '[Normal] T-RS-VLG-02: source 済みの状態で再度 source しても終了コード 0 で stderr は空'
        When call _resource_lib_in_fresh_shell
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: existing validation functions keep their error output after the guarded source
    Context 'When: 異常系'
      It '[Error] T-RS-VLG-03: ガード付きで source 後も validate_symbol の不正値エラーは従来形式 (::error::field:) で出力される'
        When call _validate_symbol_in_fresh_shell 'a b' field '^[a-z]+$'
        The status should not equal 0
        The stderr should start with '::error::field:'
      End
    End

    # エッジケース: the guard variable is already set before the library is sourced
    Context 'When: エッジケース'
      It '[Edge] T-RS-VLG-04: VALIDATION_LIB_LOADED=1 設定済みで source すると終了コード 0 で関数を定義せずに戻る'
        When call _source_lib_in_fresh_shell 1
        The status should equal 0
        The line 2 of output should equal 'validate_symbol=undefined'
        The line 3 of output should equal 'validate_positive_int=undefined'
        The line 4 of output should equal 'source_status=0'
      End
    End
  End
End
