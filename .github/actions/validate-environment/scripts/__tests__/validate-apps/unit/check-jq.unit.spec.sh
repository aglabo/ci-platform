#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/unit/check-jq.unit.spec.sh
# @(#) : Unit tests for check_jq() in validate-apps.sh

Describe 'check_jq()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"

  Context 'when jq is available'
    It 'returns success'
      When call check_jq
      The status should be success
    End

    It 'outputs nothing to stderr'
      When call check_jq
      The status should be success
      The stderr should be blank
    End
  End

  Context 'when jq is not available'
    setup_empty_path() {
      RM_CMD=$(command -v rm)
      EMPTY_DIR=$(mktemp -d)
      SAVED_PATH="$PATH"
      PATH="$EMPTY_DIR"
    }
    teardown_empty_path() {
      PATH="$SAVED_PATH"
      "$RM_CMD" -rf "$EMPTY_DIR"
    }
    BeforeEach 'setup_empty_path'
    AfterEach 'teardown_empty_path'

    It 'returns failure'
      When call check_jq
      The status should be failure
      The stderr should not be blank
    End

    It 'outputs jq required message to stderr'
      When call check_jq
      The status should be failure
      The stderr should include "jq is required for JSON processing"
    End

    It 'outputs install instructions to stderr'
      When call check_jq
      The status should be failure
      The stderr should include "Install:"
    End
  End
End
