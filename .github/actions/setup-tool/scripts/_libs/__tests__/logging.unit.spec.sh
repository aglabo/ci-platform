#!/usr/bin/env bash
# src: ./.github/actions/setup-tool/scripts/_libs/__tests__/logging.unit.spec.sh
# @(#) : Test suite for logging.lib.sh
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
#
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# Module: composite-action/setup-tool
# Target: _libs/logging.lib.sh
# Tasks: T-00

Describe 'logging.lib.sh'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/logging.lib.sh"
  Include "$LIB_PATH"

  # ─────────────────────────────────────────────────────────
  # T-00-01: make_error_message
  # ─────────────────────────────────────────────────────────
  Describe 'T-00-01: make_error_message()'
    # T-00-01-01
    It 'returns ::error::field: msg for valid field and message'
      When call make_error_message "tool-name" "invalid value 'MyTool'"
      The status should be success
      The output should equal "::error::tool-name: invalid value 'MyTool'"
    End

    # T-00-01-02
    It 'returns ::error:: prefix even when field is empty'
      When call make_error_message "" "some error"
      The status should be success
      The output should equal "::error::: some error"
    End
  End

  # ─────────────────────────────────────────────────────────
  # T-00-02: make_warning_message
  # ─────────────────────────────────────────────────────────
  Describe 'T-00-02: make_warning_message()'
    # T-00-02-01
    It 'returns ::warning::field: msg for valid field and message'
      When call make_warning_message "tool-name" "deprecated format"
      The status should be success
      The output should equal "::warning::tool-name: deprecated format"
    End
  End

  # ─────────────────────────────────────────────────────────
  # T-00-03: make_notice_message
  # ─────────────────────────────────────────────────────────
  Describe 'T-00-03: make_notice_message()'
    # T-00-03-01
    It 'returns ::notice::msg for a message'
      When call make_notice_message "setup complete"
      The status should be success
      The output should equal "::notice::setup complete"
    End
  End
End
