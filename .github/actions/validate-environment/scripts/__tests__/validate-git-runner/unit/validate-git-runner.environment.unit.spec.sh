#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Environment Unit'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  Describe 'check_env_var()'
    Context 'existence check only'
      BeforeEach 'setup_test_var'
      AfterEach 'cleanup_test_var'

      setup_test_var() {
        export TEST_VAR="value"
      }

      cleanup_test_var() {
        unset TEST_VAR
      }

      It 'returns success when variable exists'
        When call check_env_var "TEST_VAR"
        The status should be success
      End
    End

    Context 'value matching'
      BeforeEach 'setup_test_var_match'
      AfterEach 'cleanup_test_var_match'

      setup_test_var_match() {
        export TEST_VAR="expected"
      }

      cleanup_test_var_match() {
        unset TEST_VAR
      }

      It 'returns success when variable matches expected value'
        When call check_env_var "TEST_VAR" "expected"
        The status should be success
      End

      It 'returns failure when variable value mismatches'
        When call check_env_var "TEST_VAR" "different"
        The status should be failure
      End
    End

    Context 'variable not set'
      BeforeEach 'cleanup_test_var_unset'
      AfterEach 'cleanup_test_var_unset'

      cleanup_test_var_unset() {
        unset TEST_VAR
      }

      It 'returns failure when variable not set'
        When call check_env_var "TEST_VAR"
        The status should be failure
      End
    End

    Context 'empty string values'
      BeforeEach 'setup_empty_var'
      AfterEach 'cleanup_empty_var'

      setup_empty_var() {
        export TEST_VAR=""
      }

      cleanup_empty_var() {
        unset TEST_VAR
      }

      It 'returns failure when variable is empty'
        When call check_env_var "TEST_VAR"
        The status should be failure
      End
    End

    Context 'special characters in values'
      BeforeEach 'setup_special_chars'
      AfterEach 'cleanup_special_chars'

      setup_special_chars() {
        export TEST_VAR="value-with-special_chars.123"
      }

      cleanup_special_chars() {
        unset TEST_VAR
      }

      It 'handles special characters correctly'
        When call check_env_var "TEST_VAR" "value-with-special_chars.123"
        The status should be success
      End
    End

    Context 'special value types'
      AfterEach 'cleanup_special_type_var'

      cleanup_special_type_var() {
        unset TEST_VAR
      }

      It 'returns success when variable is space-only (non-empty)'
        export TEST_VAR=" "
        When call check_env_var "TEST_VAR"
        The status should be success
      End

      It 'returns success for numeric value'
        export TEST_VAR="42"
        When call check_env_var "TEST_VAR"
        The status should be success
      End

      It 'returns success when value with spaces matches expected'
        export TEST_VAR="hello world"
        When call check_env_var "TEST_VAR" "hello world"
        The status should be success
      End
    End
  End
End
