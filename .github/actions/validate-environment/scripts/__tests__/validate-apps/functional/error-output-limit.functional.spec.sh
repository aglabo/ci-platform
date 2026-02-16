#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for error output limit functionality
# Tests MAX_ERROR_DISPLAY global variable and output truncation

Describe 'Error output limit (MAX_ERROR_DISPLAY)'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Setup and teardown for each test
  BeforeEach 'setup_test'
  AfterEach 'teardown_test'

  setup_test() {
    # Reset global variables
    declare -g -a VALIDATION_RESULTS=()
    declare -g VALIDATION_INDEX=0

    # Create temporary output file
    GITHUB_OUTPUT=$(mktemp)
  }

  teardown_test() {
    # Clean up
    unset VALIDATION_RESULTS
    unset VALIDATION_INDEX
    [ -f "$GITHUB_OUTPUT" ] && rm -f "$GITHUB_OUTPUT"
  }

  Context 'default MAX_ERROR_DISPLAY (50 errors)'
    It 'displays all errors when count is less than limit (10 errors)'
      # Create 10 errors
      for i in {1..10}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Error message 1"
      The stderr should include "Error message 10"
      The stderr should not include "... and"
    End

    It 'truncates output when errors exceed limit (60 errors)'
      # Create 60 errors
      for i in {1..60}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Error message 1"
      The stderr should include "Error message 50"
      The stderr should not include "Error message 51"
      The stderr should include "... and 10 more error(s) (total: 60)"
    End

    It 'shows exactly at limit (50 errors)'
      # Create exactly 50 errors
      for i in {1..50}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Error message 1"
      The stderr should include "Error message 50"
      The stderr should not include "... and"
    End

    It 'shows truncation at limit+1 (51 errors)'
      # Create 51 errors (just over limit)
      for i in {1..51}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Error message 1"
      The stderr should include "Error message 50"
      The stderr should not include "Error message 51"
      The stderr should include "... and 1 more error(s) (total: 51)"
    End
  End

  Context 'custom MAX_ERROR_DISPLAY (10 errors)'
    Parameters
      15 10  # 15 errors with limit 10
      25 10  # 25 errors with limit 10
      100 10 # 100 errors with limit 10
    End

    It "limits output to ${2} when MAX_ERROR_DISPLAY=${2} (${1} total errors)"
      # Set custom limit
      MAX_ERROR_DISPLAY=$2

      # Create specified number of errors
      for i in $(seq 1 "$1"); do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Error message 1"
      The stderr should include "Error message ${2}"

      # Calculate expected remaining
      local expected_remaining=$(($1 - $2))
      The stderr should include "... and ${expected_remaining} more error(s) (total: ${1})"
    End
  End

  Context 'GITHUB_OUTPUT content verification'
    It 'includes truncation message in GITHUB_OUTPUT when errors exceed limit'
      # Create 60 errors
      for i in {1..60}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Application validation failed"
      The contents of file "$GITHUB_OUTPUT" should include "Error message 1"
      The contents of file "$GITHUB_OUTPUT" should include "Error message 50"
      The contents of file "$GITHUB_OUTPUT" should not include "Error message 51"
      The contents of file "$GITHUB_OUTPUT" should include "... and 10 more error(s) (total: 60)"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=60"
    End

    It 'does not include truncation message when errors are within limit'
      # Create 30 errors
      for i in {1..30}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "Application validation failed"
      The contents of file "$GITHUB_OUTPUT" should include "Error message 1"
      The contents of file "$GITHUB_OUTPUT" should include "Error message 30"
      The contents of file "$GITHUB_OUTPUT" should not include "... and"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=30"
    End
  End

  Context 'metadata accuracy'
    It 'reports correct failed_count regardless of display limit'
      # Create 100 errors
      for i in {1..100}; do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=100"
      The stderr should include "... and 50 more error(s) (total: 100)"
    End
  End
End
