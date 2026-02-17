#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/__tests__/integration/output-limit.integration.spec.sh
# ShellSpec integration tests for output limit feature
# Tests MAX_ERROR_DISPLAY limit and large-scale data handling

Describe 'output limit feature'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  Include "$SCRIPT_PATH"

  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT=$(mktemp)
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT"
  }

  # ========================================
  # output_validation_errors_json() - Output Limit
  # ========================================
  Describe 'output_validation_errors_json() - output limit'

    Context 'when errors exceed MAX_ERROR_DISPLAY (50)'
      BeforeEach 'setup_150_errors'
      setup_150_errors() {
        for i in $(seq 1 150); do
          add_validation_result "app${i}" "App${i}" "error" "" "Error ${i}"
        done
      }

      It 'shows only first 50 errors'
        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # stderr: Header
        The stderr should include "=== Application validation failed ==="

        # First 50 errors should appear in GITHUB_OUTPUT
        The contents of file "$GITHUB_OUTPUT" should include "  Error 1"
        The contents of file "$GITHUB_OUTPUT" should include "  Error 50"
      End

      It 'adds truncation message in stderr'
        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # Truncation message in stderr
        The stderr should include "... and 100 more error(s) (total: 150)"
      End

      It 'adds truncation message in GITHUB_OUTPUT'
        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # stderr: Header
        The stderr should include "=== Application validation failed ==="

        # Truncation message in GITHUB_OUTPUT
        The contents of file "$GITHUB_OUTPUT" should include "... and 100 more error(s) (total: 150)"
      End

      It 'preserves accurate total count'
        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # stderr: Header
        The stderr should include "=== Application validation failed ==="

        # Metadata count is accurate despite truncation
        The contents of file "$GITHUB_OUTPUT" should include "failed_count=150"
        The contents of file "$GITHUB_OUTPUT" should include "validated_count=0"
      End

      It 'does not show errors beyond limit'
        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # stderr: Header
        The stderr should include "=== Application validation failed ==="

        # Errors beyond first 50 should NOT appear in GITHUB_OUTPUT
        The contents of file "$GITHUB_OUTPUT" should not include "  Error 51"
        The contents of file "$GITHUB_OUTPUT" should not include "  Error 150"
      End
    End

    Context 'with large number of errors (500+)'
      It 'handles 500+ errors without error'
        for i in $(seq 1 500); do
          add_validation_result "app${i}" "Application${i}" "error" "" "Error message ${i}"
        done

        When call output_validation_errors_json VALIDATION_RESULTS
        The status should be failure

        # stderr: Header
        The stderr should include "=== Application validation failed ==="

        # Verify count
        The contents of file "$GITHUB_OUTPUT" should include "failed_count=500"
      End
    End
  End

  # ========================================
  # output_validation_success_json() - Large Scale
  # ========================================
  Describe 'output_validation_success_json() - large scale'
    Context 'with large number of successes (500+)'
      It 'handles 500+ validations without error'
        for i in $(seq 1 500); do
          add_validation_result "app${i}" "Application${i}" "success" "version${i}.0.0" ""
        done

        When call output_validation_success_json VALIDATION_RESULTS
        The status should be success

        # stderr: Header
        The stderr should include "=== Application validation passed ==="

        # Verify count
        The contents of file "$GITHUB_OUTPUT" should include "validated_count=500"
      End
    End
  End
End
