#!/usr/bin/env bash
# src: ./.github/actions/setup-tool/scripts/_libs/__tests__/validate-repository.unit.spec.sh
# @(#) : Test suite for validate_repository() function
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
# Tasks: T-01-RF (DR-17: validate_repository)

Describe 'validate_repository()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  # ─────────────────────────────────────────────────────────
  # T-01-RF-04: 有効な repo → stdout に "org/name" を返す
  # ─────────────────────────────────────────────────────────
  Describe 'T-01-RF-04: valid repo returns "org/name" on stdout'
    It 'returns "rhysd/actionlint" for valid input'
      When call validate_repository "rhysd/actionlint"
      The status should be success
      The output should equal "rhysd/actionlint"
    End

    It 'trims leading/trailing spaces and returns normalized value'
      When call validate_repository "  rhysd/actionlint  "
      The status should be success
      The output should equal "rhysd/actionlint"
    End
  End

  # ─────────────────────────────────────────────────────────
  # T-01-RF-05: 無効な repo → return 1 + stderr に ::error::repo:
  # ─────────────────────────────────────────────────────────
  Describe 'T-01-RF-05: invalid repo returns 1 and emits ::error::repo: to stderr'
    It 'returns 1 for extra slash "org/repo/extra"'
      When call validate_repository "org/repo/extra"
      The status should be failure
      The stderr should include "::error::repo:"
    End

    It 'returns 1 for missing slash "orgonly"'
      When call validate_repository "orgonly"
      The status should be failure
      The stderr should include "::error::repo:"
    End

    It 'returns 1 for empty value'
      When call validate_repository ""
      The status should be failure
      The stderr should include "::error::repo:"
    End

    It 'returns 1 for invalid org part (uppercase "Org/repo")'
      When call validate_repository "Org/repo"
      The status should be failure
      The stderr should include "::error::repo:"
    End

    It 'returns 1 for leading slash "/repo"'
      When call validate_repository "/repo"
      The status should be failure
      The stderr should include "::error::repo:"
    End

    It 'returns 1 for trailing slash "org/"'
      When call validate_repository "org/"
      The status should be failure
      The stderr should include "::error::repo:"
    End
  End
End
