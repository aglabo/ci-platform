#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/__tests__/e2e/validate-apps/validate-apps.e2e.spec.sh
# @(#) : E2E tests for main() - end-user facing orchestrator in validate-apps.sh

Describe 'main() - E2E'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"

  BeforeEach 'setup_test'
  AfterEach 'cleanup_test'

  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
    APPS=()
  }

  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
  }

  # ============================================================================
  # Success cases
  # ============================================================================

  Describe 'success cases'
    It 'validates default apps (git + curl) successfully'
      run_main() { main < /dev/null; }
      When call run_main
      The status should be success
      The output should include "=== Validating Required Applications ==="
      The stderr should include "Application validation passed"
    End

    It 'writes status=success to GITHUB_OUTPUT'
      check_output_status() {
        main < /dev/null > /dev/null
        grep "^status=" "$GITHUB_OUTPUT_FILE" | tr -d '\r'
      }
      When call check_output_status
      The output should equal "status=success"
      The stderr should not be blank
    End

    It 'writes message with Git and curl to GITHUB_OUTPUT'
      check_output_message() {
        main < /dev/null > /dev/null
        grep -A20 "^message<<" "$GITHUB_OUTPUT_FILE" | tr -d '\r'
      }
      When call check_output_message
      The output should include "Git"
      The output should include "curl"
      The stderr should not be blank
    End
  End

  # ============================================================================
  # Failure cases
  # ============================================================================

  Describe 'failure cases'
    It 'returns failure when additional app via stdin does not exist'
      run_main_with_bad_app() {
        echo "nonExistentCmd12345|NonExistent" | main
      }
      When call run_main_with_bad_app
      The status should be failure
      The output should include "=== Validating Required Applications ==="
      The stderr should include "NonExistent is not installed"
    End

    It 'writes status=error to GITHUB_OUTPUT on failure'
      check_error_status() {
        echo "nonExistentCmd12345|NonExistent" | main > /dev/null || true
        grep "^status=" "$GITHUB_OUTPUT_FILE" | tr -d '\r'
      }
      When call check_error_status
      The output should equal "status=error"
      The stderr should not be blank
    End

  End
End
