#!/usr/bin/env bash
# src: ./.github/actions/setup-tool/scripts/_libs/__tests__/validate-tool-name.unit.spec.sh
# @(#) : Test suite for validate_tool_name() function
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# Module: composite-action/setup-tool
# Target: _libs/validation.lib.sh
# Tasks: T-01-RF (DR-16: 2-layer design)

Describe 'validate_tool_name()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  # ─────────────────────────────────────────────────────────
  # T-01-RF-01: 有効な値 → stdout に正規化済み値を返す
  # ─────────────────────────────────────────────────────────
  Describe 'T-01-RF-01: valid value returns normalized name on stdout'
    It 'returns "actionlint" for valid lowercase input'
      When call validate_tool_name "actionlint"
      The status should be success
      The output should equal "actionlint"
    End

    It 'returns "my-tool_v2" for valid input with digits/hyphens/underscores'
      When call validate_tool_name "my-tool_v2"
      The status should be success
      The output should equal "my-tool_v2"
    End
  End

  # ─────────────────────────────────────────────────────────
  # T-01-RF-02: 無効な値 → return 1 + stderr に ::error::
  # ─────────────────────────────────────────────────────────
  Describe 'T-01-RF-02: invalid value returns 1 and emits ::error:: to stderr'
    It 'returns 1 for uppercase value "MyTool" and emits ::error:: to stderr'
      When call validate_tool_name "MyTool"
      The status should be failure
      The stderr should include "::error::tool-name:"
    End

    It 'returns 1 for empty value and emits ::error:: to stderr'
      When call validate_tool_name ""
      The status should be failure
      The stderr should include "::error::tool-name:"
    End

    It 'returns 1 for 65-char value exceeding max length'
      local long_val
      long_val="$(printf 'a%.0s' {1..65})"
      When call validate_tool_name "$long_val"
      The status should be failure
      The stderr should include "::error::tool-name:"
    End
  End

  # ─────────────────────────────────────────────────────────
  # T-01-RF-03: trim — 前後空白を除去して検証
  # ─────────────────────────────────────────────────────────
  Describe 'T-01-RF-03: leading/trailing whitespace is trimmed before validation'
    It 'trims leading/trailing spaces and returns normalized value'
      When call validate_tool_name "  actionlint  "
      The status should be success
      The output should equal "actionlint"
    End

    It 'returns 1 for whitespace-only input after trim'
      When call validate_tool_name "   "
      The status should be failure
      The stderr should include "::error::tool-name:"
    End
  End

  # ─────────────────────────────────────────────────────────
  # 境界値
  # ─────────────────────────────────────────────────────────
  Describe 'boundary values'
    It 'accepts exactly 64-char value (maximum length)'
      local max_val
      max_val="$(printf 'a%.0s' {1..64})"
      When call validate_tool_name "$max_val"
      The status should be success
      The output should equal "$max_val"
    End

    It 'accepts single-char value "a" (minimum length)'
      When call validate_tool_name "a"
      The status should be success
      The output should equal "a"
    End
  End
End
