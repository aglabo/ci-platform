#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/functional/handle-validation-error.functional.spec.sh
# @(#) : Functional tests for handle_validation_error() in validate-apps.sh

Describe 'handle_validation_error()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"

  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
  }

  Describe 'default behavior (fail-fast)'
    It 'returns failure status'
      When call handle_validation_error "git" "Git" "2.39.0" "Git version too old"
      The status should be failure
      The stderr should not be blank
    End

    It 'outputs error message to stderr with ::error:: prefix'
      When call handle_validation_error "git" "Git" "2.39.0" "Git version too old"
      The status should be failure
      The stderr should include "::error::Git version too old"
    End

    It 'writes status=error to GITHUB_OUTPUT'
      When call handle_validation_error "git" "Git" "2.39.0" "Git version too old"
      The status should be failure
      The stderr should not be blank
      The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
    End

    It 'writes failed_apps to GITHUB_OUTPUT'
      When call handle_validation_error "git" "Git" "2.39.0" "Git version too old"
      The status should be failure
      The stderr should not be blank
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_apps=Git"
    End

    It 'writes message to GITHUB_OUTPUT'
      When call handle_validation_error "git" "Git" "2.39.0" "Git version too old"
      The status should be failure
      The stderr should not be blank
      The contents of file "$GITHUB_OUTPUT_FILE" should include "message=Git version too old"
    End

    It 'adds entry to VALIDATION_RESULTS array'
      check_results_count() {
        handle_validation_error "git" "Git" "2.39.0" "Git version too old" || true
        echo "${#VALIDATION_RESULTS[@]}"
      }
      When call check_results_count
      The output should equal 1
      The stderr should not be blank
    End
  End
End
