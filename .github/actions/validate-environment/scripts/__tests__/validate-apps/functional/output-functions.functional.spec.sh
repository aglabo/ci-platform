#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/functional/output-functions.functional.spec.sh
# @(#) : Functional tests for output functions in validate-apps.sh
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
# This software is released under the MIT License.

#|
#| Unit tests for JSON output functions:
#| - output_validation_success_json()
#| - output_validation_errors_json()
#| Target: Basic fast-feedback tests for single validation scenarios
#|
#| Note: Comprehensive coverage for multiple validations, edge cases,
#| and complex scenarios is provided by integration tests:
#| - .github/actions/__tests__/integration/output-validation-success-json.integration.spec.sh
#| - .github/actions/__tests__/integration/output-validation-errors-json.integration.spec.sh
#|

Describe 'validate-apps.sh output functions'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Setup test environment before each test
  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
    # Initialize global array and counters (don't use declare -a for global scope)
    RESULTS=()
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  # Cleanup after each test
  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
    unset RESULTS
  }

  # ============================================================================
  # output_validation_success_json() - 4 tests
  # ============================================================================

  Describe 'output_validation_success_json()'
    Context 'with single successful validation'
      It 'outputs correct JSON structure'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The error should include "Application validation passed"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
      End

      It 'includes application name and version'
        RESULTS=(
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The error should include "=== Application validation passed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "jq 1.6"
      End

      It 'sets validated_count to 1'
        RESULTS=(
          '{"app":"bash","version":"5.1","status":"success","message":"bash is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The error should include "=== Application validation passed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=1"
      End

      It 'sets failed_count to 0'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The error should include "=== Application validation passed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
      End
    End
  End

  # ============================================================================
  # output_validation_errors_json() - 5 tests
  # ============================================================================

  Describe 'output_validation_errors_json()'
    Context 'with single error'
      It 'returns failure status'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "Application validation failed"
      End

      It 'outputs error to stderr with ::error:: prefix'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "::error::  - missing is not installed"
      End

      It 'sets failed_count to 1'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "=== Application validation failed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=1"
      End

      It 'sets status to error in GITHUB_OUTPUT'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "=== Application validation failed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
      End

      It 'includes error message in output'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "=== Application validation failed ==="
        The contents of file "$GITHUB_OUTPUT_FILE" should include "missing is not installed"
      End
    End
  End
End
