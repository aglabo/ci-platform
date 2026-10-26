#!/usr/bin/env bash
# src: .github/actions/_libs/validation.lib.sh
# @(#) : validation utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for validate_positive_int in validation.lib.sh
# Module: composite-action/resolve-sha (test_scope RS, target VPI)
# Target: _libs/validation.lib.sh
# Function: validate_positive_int <value> <max>

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"

# --- 内部ヘルパー ---
# 定数

## Upper bound passed as <max> in every case (tasks.md T-02 premise).
_VPI_MAX=1000

## Value "1" followed by non-ASCII superscript two; used by T-RS-VPI-15.
_VPI_SUPERSCRIPT_VALUE="1²"

## UTF-8 locale (other than C.UTF-8) whose collation puts '²' inside 0-9; used by T-RS-VPI-15.
_VPI_UTF8_LOCALE="en_US.UTF-8"

# 関数

##
# Run validate_positive_int with LC_ALL set to a UTF-8 locale (function-local, so
# it never leaks between examples), to prove the format check does not depend on
# the caller's locale collation.
# @arg $1 value — the value to validate
# @arg $2 max   — upper bound
# @return validate_positive_int's exit code
_vpi_run_utf8() {
  local LC_ALL="$_VPI_UTF8_LOCALE"
  validate_positive_int "$@"
}

# --- テスト本体 ---

##
# validation.lib.sh: shared validation helpers for composite actions.
# Assigned test IDs: T-RS-VPI-01 .. T-RS-VPI-09, T-RS-VPI-11 .. T-RS-VPI-15 (T-RS-VPI-10 retired: duplicate of T-RS-VPI-09)
Describe 'validation.lib.sh'
  ##
  # validate_positive_int: accept a positive integer within 1..<max>, report by exit status only.
  # Scenarios: positive integers within the allowed range are accepted;
  #            values whose format is not a positive integer are rejected,
  #            including non-ASCII digits under a UTF-8 locale (C-locale matching);
  #            values above <max> are rejected without any output;
  #            values with more digits than <max> are rejected before 64-bit overflow can occur.
  Describe 'validate_positive_int'
    # 正常系: positive integers within 1..<max>
    Context 'When: 正常系'
      It '[Normal] T-RS-VPI-01: "1" (max 1000) -> 終了コード 0'
        When call validate_positive_int "1" "$_VPI_MAX"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-RS-VPI-02: "1000" (max 1000) -> 終了コード 0'
        When call validate_positive_int "1000" "$_VPI_MAX"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # 異常系: values whose format is not a positive integer, values above <max>, or an invalid <max> (exit 2)
    Context 'When: 異常系'
      It '[Error] T-RS-VPI-03: "0" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "0" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-04: "-1" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "-1" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-05: "abc" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "abc" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-06: "01" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "01" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-07: " 2" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int " 2" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-08: "" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-09: "1001" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "1001" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-15: "1²" (max 1000, UTF-8 ロケール) -> 終了コード 0 以外、stderr は空'
        When call _vpi_run_utf8 "$_VPI_SUPERSCRIPT_VALUE" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-16: "1" (max "9223372036854775807", 19 桁) -> 終了コード 2'
        When call validate_positive_int "1" "9223372036854775807"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-17: "1" (max "0") -> 終了コード 2'
        When call validate_positive_int "1" "0"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-18: "1" (max "") -> 終了コード 2'
        When call validate_positive_int "1" ""
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-VPI-19: "1" (max "01") -> 終了コード 2'
        When call validate_positive_int "1" "01"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # エッジケース: values with more digits than <max>, including 64-bit overflow inputs
    Context 'When: エッジケース'
      It '[Edge] T-RS-VPI-11: "10000" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "10000" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-VPI-12: "12345678901234567890" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "12345678901234567890" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-VPI-13: "18446744073709551617" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "18446744073709551617" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-VPI-14: "9223372036854775808" (max 1000) -> 終了コード 0 以外'
        When call validate_positive_int "9223372036854775808" "$_VPI_MAX"
        The status should not equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-RS-VPI-20: "999999999999999999" (max "999999999999999999", 18 桁) -> 終了コード 0'
        When call validate_positive_int "999999999999999999" "999999999999999999"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End
    End
  End
End
