#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/unit/output-functions.unit.spec.sh
# @(#) : Unit tests for output functions in validate-apps.sh
#
# Copyright (c) 2026- aglabo <https://github.com/aglabo>
# This software is released under the MIT License.

#|
#| Unit tests for JSON output functions:
#| - output_validation_success_json()
#| - output_validation_errors_json()
#| Target: 15-20 tests for output formatting and edge cases
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
  # output_validation_success_json() - 10 tests
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
        The contents of file "$GITHUB_OUTPUT_FILE" should include "jq 1.6"
      End

      It 'sets validated_count to 1'
        RESULTS=(
          '{"app":"bash","version":"5.1","status":"success","message":"bash is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=1"
      End

      It 'sets failed_count to 0'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
      End
    End

    Context 'with multiple successful validations'
      It 'outputs all applications in multiline format'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
          '{"app":"bash","version":"5.1","status":"success","message":"bash is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "git 2.39.0"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "jq 1.6"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "bash 5.1"
      End

      It 'sets validated_count correctly'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
      End

      It 'outputs validated_apps as comma-separated list'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=git,jq"
      End
    End

    Context 'with mixed success and error results'
      It 'outputs only successful validations'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "git 2.39.0"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "jq 1.6"
      End

      It 'excludes error results from validated_apps'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=git"
      End
    End

    Context 'with special characters in application names'
      It 'handles hyphens in application names'
        RESULTS=(
          '{"app":"node-js","version":"18.0.0","status":"success","message":"node-js is installed"}'
        )
        When call output_validation_success_json RESULTS
        The status should be success
        The contents of file "$GITHUB_OUTPUT_FILE" should include "node-js 18.0.0"
      End
    End
  End

  # ============================================================================
  # output_validation_errors_json() - 10 tests
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
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=1"
      End

      It 'sets status to error in GITHUB_OUTPUT'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
      End

      It 'includes error message in output'
        RESULTS=(
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "missing is not installed"
      End
    End

    Context 'with multiple errors'
      It 'counts all errors correctly'
        RESULTS=(
          '{"app":"missing1","version":"","status":"error","message":"missing1 is not installed"}'
          '{"app":"missing2","version":"","status":"error","message":"missing2 is not installed"}'
          '{"app":"missing3","version":"","status":"error","message":"missing3 is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=3"
      End

      It 'outputs all error messages to stderr'
        RESULTS=(
          '{"app":"missing1","version":"","status":"error","message":"missing1 is not installed"}'
          '{"app":"missing2","version":"","status":"error","message":"missing2 is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The error should include "::error::  - missing1 is not installed"
        The error should include "::error::  - missing2 is not installed"
      End

      It 'outputs failed_apps as comma-separated list'
        RESULTS=(
          '{"app":"missing1","version":"","status":"error","message":"missing1 is not installed"}'
          '{"app":"missing2","version":"","status":"error","message":"missing2 is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_apps=missing1,missing2"
      End
    End

    Context 'with mixed success and error results'
      It 'calculates validated_count from successful validations'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"jq","version":"1.6","status":"success","message":"jq is installed"}'
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
      End

      It 'only includes failed apps in failed_apps list'
        RESULTS=(
          '{"app":"git","version":"2.39.0","status":"success","message":"git is installed"}'
          '{"app":"missing","version":"","status":"error","message":"missing is not installed"}'
        )
        When call output_validation_errors_json RESULTS
        The status should be failure
        The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_apps=missing"
      End
    End
  End
End
