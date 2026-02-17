#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/integration/validate-apps-orchestrator.integration.spec.sh
# @(#) : Integration tests for validate_apps() orchestration in validate-apps.sh

Describe 'validate_apps()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"

  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
    FAIL_FAST="true"
  }

  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
  }

  Describe 'success cases'
    It 'succeeds with 2-field format (cmd|app_name)'
      When call validate_apps "git|Git"
      The status should be success
      The stderr should not be blank
    End

    It 'succeeds with 4-field format (cmd|app_name|extractor|min_ver)'
      When call validate_apps "git|Git|field:3|2.0"
      The status should be success
      The stderr should not be blank
    End

    It 'succeeds with multiple valid apps'
      When call validate_apps "git|Git" "bash|Bash"
      The status should be success
      The stderr should not be blank
    End

    It 'stores 2 results for 2 successful apps'
      check_results_count() {
        validate_apps "git|Git" "bash|Bash"
        echo "${#VALIDATION_RESULTS[@]}"
      }
      When call check_results_count
      The output should equal 2
      The stderr should not be blank
    End

    It 'stores success status in VALIDATION_RESULTS'
      check_results_status() {
        validate_apps "git|Git"
        echo "${VALIDATION_RESULTS[0]}"
      }
      When call check_results_status
      The output should include '"status": "success"'
      The stderr should not be blank
    End
  End

  Describe 'failure cases'
    It 'fails with invalid format (no pipe delimiter)'
      When call validate_apps "badformat"
      The status should be failure
      The stderr should not be blank
    End

    It 'fails with non-existent command'
      When call validate_apps "nonExistentCmd12345|NonExistent"
      The status should be failure
      The stderr should not be blank
    End

    It 'fails when version requirement not met'
      When call validate_apps "git|Git|field:3|999.0"
      The status should be failure
      The stderr should not be blank
    End

    It 'stores error in VALIDATION_RESULTS on failure'
      check_results_count() {
        validate_apps "nonExistentCmd12345|NonExistent" || true
        echo "${#VALIDATION_RESULTS[@]}"
      }
      When call check_results_count
      The output should equal 1
      The stderr should not be blank
    End

    It 'stores error status in VALIDATION_RESULTS on failure'
      check_results_status() {
        validate_apps "nonExistentCmd12345|NonExistent" || true
        echo "${VALIDATION_RESULTS[0]}"
      }
      When call check_results_status
      The output should include '"status": "error"'
      The stderr should not be blank
    End
  End
End
