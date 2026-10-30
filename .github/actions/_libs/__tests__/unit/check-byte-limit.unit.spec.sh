#!/usr/bin/env bash
# src: .github/actions/_libs/__tests__/unit/check-byte-limit.unit.spec.sh
# @(#) : unit tests for validation.lib.sh (check_byte_limit)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

# Test suite for validation.lib.sh (check_byte_limit)
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: _libs/validation.lib.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# check_byte_limit tests call the function loaded by Include; T-GCF-CBL-03 sources
# the library inside a fresh bash process (see _cbl_source_lib_in_fresh_shell) so
# that the guard state of the Include does not hide a missing error.lib.sh source.
# T-GCF-CBL-10 copies the library alone (without error.lib.sh) into a temporary
# directory and sources the copy in a fresh bash process (see
# _cbl_source_isolated_copy).
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"
LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"

# --- 内部ヘルパー ---
# 定数
# Byte limit passed to check_byte_limit in the 120000-byte examples
_CBL_MAX_BYTES=120000
# 'a' x 120000 (exactly the limit); used by T-GCF-CBL-01
printf -v _CBL_ASCII_MAX_TEXT 'a%.0s' {1..120000}
# 'a' x 120001 (one byte over the limit); used by T-GCF-CBL-04
printf -v _CBL_ASCII_OVER_TEXT 'a%.0s' {1..120001}
# Caller's locale in the multibyte examples; used by T-GCF-CBL-07 .. T-GCF-CBL-09
_CBL_UTF8_LOCALE="C.UTF-8"
# 'あ' x 40001 (120003 bytes in UTF-8, one character over); used by T-GCF-CBL-07
printf -v _CBL_KANA_OVER_TEXT 'あ%.0s' {1..40001}
# 'あ' x 40000 (exactly 120000 bytes in UTF-8); used by T-GCF-CBL-08
printf -v _CBL_KANA_MAX_TEXT 'あ%.0s' {1..40000}

# 関数

##
# @description Run check_byte_limit with the caller's LC_ALL set to
#              _CBL_UTF8_LOCALE (function-local, so it never leaks between examples).
#              Used by T-GCF-CBL-07, T-GCF-CBL-08.
# @arg $@ arguments passed to check_byte_limit as is
# @stdout (none)
# @stderr whatever check_byte_limit writes to stderr
# @return exit status of check_byte_limit
_cbl_check_in_utf8() {
  local LC_ALL="$_CBL_UTF8_LOCALE"
  check_byte_limit "$@"
}

##
# @description With the caller's LC_ALL set to _CBL_UTF8_LOCALE (function-local),
#              call check_byte_limit files a.sh "$_CBL_MAX_BYTES" and print LC_ALL
#              as seen by the caller afterwards.
#              Used by T-GCF-CBL-09.
# @stdout the caller's LC_ALL after the call
# @stderr whatever check_byte_limit writes to stderr
# @return exit status of check_byte_limit
_cbl_lc_all_after_check() {
  local LC_ALL="$_CBL_UTF8_LOCALE" _rc=0
  check_byte_limit files a.sh "$_CBL_MAX_BYTES" || _rc=$?
  printf '%s' "$LC_ALL"
  return "$_rc"
}

##
# @description Source validation.lib.sh in a fresh bash process, with both
#              VALIDATION_LIB_LOADED and ERROR_LIB_LOADED unset beforehand, and
#              print whether gha_error and check_byte_limit are defined.
#              Used by T-GCF-CBL-03.
# @stdout one per line, in this order:
#         "gha_error=<defined|undefined>",
#         "check_byte_limit=<defined|undefined>",
#         "source_status=<exit status of the source>"
# @stderr whatever the source writes to stderr
# @return exit status of the fresh bash process
_cbl_source_lib_in_fresh_shell() {
  bash -c '
    unset VALIDATION_LIB_LOADED ERROR_LIB_LOADED
    . "$1"
    _source_status=$?
    for _fn in gha_error check_byte_limit; do
      if declare -F "$_fn" >/dev/null; then
        echo "${_fn}=defined"
      else
        echo "${_fn}=undefined"
      fi
    done
    echo "source_status=${_source_status}"
  ' _ "$LIB_PATH"
}

##
# @description BeforeEach of the load sequence group: create a temporary
#              directory and set _CBL_TMP_DIR to it.
#              Used by T-GCF-CBL-10.
# @stdout (none)
# @return 0 on success, non-zero when the directory cannot be created
_cbl_tmp_setup() {
  _CBL_TMP_DIR="$(mktemp -d)" || return 1
}

##
# @description AfterEach of the load sequence group: remove _CBL_TMP_DIR.
#              Used by T-GCF-CBL-10.
# @stdout (none)
# @return 0 (also when _CBL_TMP_DIR is unset), otherwise the exit status of rm
_cbl_tmp_cleanup() {
  [ -z "${_CBL_TMP_DIR:-}" ] || rm -rf "$_CBL_TMP_DIR"
}

##
# @description Copy validation.lib.sh alone (without error.lib.sh) to
#              ${_CBL_TMP_DIR}/_libs/ and source the copy in a fresh bash process,
#              with VALIDATION_LIB_LOADED and ERROR_LIB_LOADED unset beforehand.
#              Requires: _cbl_tmp_setup has been called (BeforeEach).
#              Used by T-GCF-CBL-10.
# @stdout whatever the source writes to stdout
# @stderr whatever the source writes to stderr
# @return exit status of the source of the copy (1 when the copy cannot be made)
_cbl_source_isolated_copy() {
  local _copy="${_CBL_TMP_DIR}/_libs/validation.lib.sh"
  mkdir -p "${_copy%/*}" || return 1
  cp "$LIB_PATH" "$_copy" || return 1
  bash -c '
    unset VALIDATION_LIB_LOADED ERROR_LIB_LOADED
    . "$1"
  ' _ "$_copy"
}

# --- テスト本体 ---

##
# validation.lib.sh: shared validation helpers for composite actions.
Describe 'validation.lib.sh'
  ##
  # check_byte_limit: accept a value of at most <max> bytes; report a longer one
  # via gha_error and return 1. The length is a byte count whatever the caller's locale is.
  # Scenarios: values within the limit (exactly the limit, below it) are accepted;
  #            sourcing the library also loads gha_error from error.lib.sh;
  #            a value over the limit is reported with the given target and max;
  #            an empty value, multibyte text and the caller's LC_ALL are edge cases.
  Describe 'check_byte_limit'
    # 正常系: values within the limit, and loading the library in a fresh shell
    Context 'When: 正常系'
      It '[Normal] T-GCF-CBL-01: 上限ちょうどを受け付ける'
        When call check_byte_limit files "$_CBL_ASCII_MAX_TEXT" "$_CBL_MAX_BYTES"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-GCF-CBL-02: 上限未満の値を受け付ける'
        When call check_byte_limit files a.sh "$_CBL_MAX_BYTES"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-GCF-CBL-03: validation.lib.sh を読むと gha_error も定義される'
        When call _cbl_source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'gha_error=defined'
        The line 2 of output should equal 'check_byte_limit=defined'
        The line 3 of output should equal 'source_status=0'
        The lines of output should equal 3
        The stderr should equal ''
      End
    End

    # 異常系: values over the limit are reported via gha_error with return 1
    Context 'When: 異常系'
      It '[Error] T-GCF-CBL-04: 1 バイト超過はエラー'
        When call check_byte_limit files "$_CBL_ASCII_OVER_TEXT" "$_CBL_MAX_BYTES"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120001')"
        The lines of stderr should equal 1
      End

      It '[Error] T-GCF-CBL-05: 上限 3 に 4 バイトはエラー'
        When call check_byte_limit patterns abcd 3
        The status should equal 1
        The stdout should equal ''
        The stderr should equal "::error::patterns: exceeds the limit of 3 bytes (got: '4')"
      End
    End

    # エッジケース: empty value, multibyte text under a UTF-8 caller, caller's LC_ALL
    Context 'When: エッジケース'
      It '[Edge] T-GCF-CBL-06: 空文字列を受け付ける'
        When call check_byte_limit files "" "$_CBL_MAX_BYTES"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-GCF-CBL-07: 日本語 40001 字 (120003 バイト) はエラー'
        When call _cbl_check_in_utf8 files "$_CBL_KANA_OVER_TEXT" "$_CBL_MAX_BYTES"
        The status should equal 1
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120003')"
      End

      It '[Edge] T-GCF-CBL-08: 日本語 40000 字 (120000 バイト) は受け付ける'
        When call _cbl_check_in_utf8 files "$_CBL_KANA_MAX_TEXT" "$_CBL_MAX_BYTES"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-GCF-CBL-09: 呼び出し元のロケールを変えない'
        When call _cbl_lc_all_after_check
        The status should equal 0
        The stdout should equal "$_CBL_UTF8_LOCALE"
        The stderr should equal ''
      End
    End
  End

  ##
  # load sequence: sourcing the library fails when error.lib.sh cannot be loaded.
  # Scenarios: when error.lib.sh is missing next to the library, the source
  #            returns a non-zero status.
  Describe 'load sequence'
    BeforeEach '_cbl_tmp_setup'
    AfterEach '_cbl_tmp_cleanup'

    # 異常系: error.lib.sh is missing next to the library
    Context 'When: 異常系'
      It '[Error] T-GCF-CBL-10: error.lib.sh が無いと読み込みは失敗する'
        When call _cbl_source_isolated_copy
        The status should not equal 0
        The stdout should equal ''
        The stderr should include 'error.lib.sh'
      End
    End
  End
End
