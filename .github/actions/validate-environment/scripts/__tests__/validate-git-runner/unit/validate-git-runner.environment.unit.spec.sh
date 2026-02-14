#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Environment Validation'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Helper Functions Tests
  # ============================================================================

  Describe 'get_github_output_file()'
    Context 'when GITHUB_OUTPUT is set'
      BeforeEach 'setup_github_output'
      AfterEach 'cleanup_github_output'

      setup_github_output() {
        export GITHUB_OUTPUT="/tmp/test-output"
      }

      cleanup_github_output() {
        unset GITHUB_OUTPUT
      }

      It 'returns GITHUB_OUTPUT value'
        When call get_github_output_file
        The output should eq "/tmp/test-output"
        The status should be success
      End
    End

    Context 'when GITHUB_OUTPUT is not set'
      BeforeEach 'cleanup_github_output'
      AfterEach 'cleanup_github_output'

      cleanup_github_output() {
        unset GITHUB_OUTPUT
      }

      It 'returns /dev/null'
        When call get_github_output_file
        The output should eq "/dev/null"
        The status should be success
      End
    End

    Context 'dynamic evaluation support'
      It 'evaluates GITHUB_OUTPUT each call'
        export GITHUB_OUTPUT="/tmp/first"
        first_call=$(get_github_output_file)
        export GITHUB_OUTPUT="/tmp/second"
        second_call=$(get_github_output_file)
        unset GITHUB_OUTPUT

        The value "$first_call" should eq "/tmp/first"
        The value "$second_call" should eq "/tmp/second"
      End
    End
  End

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
  End

  # ============================================================================
  # GitHub Actions Environment Tests
  # ============================================================================

  Describe 'validate_github_actions_env()'
    BeforeEach 'cleanup_github_actions'
    AfterEach 'cleanup_github_actions'

    cleanup_github_actions() {
      unset GITHUB_ACTIONS
    }

    Context 'valid GitHub Actions environment'
      It 'returns success when GITHUB_ACTIONS=true'
        export GITHUB_ACTIONS="true"
        When call validate_github_actions_env
        The status should be success
      End
    End

    Context 'invalid GitHub Actions environment'
      It 'returns failure when GITHUB_ACTIONS=false'
        export GITHUB_ACTIONS="false"
        When call validate_github_actions_env
        The status should be failure
      End

      It 'returns failure when GITHUB_ACTIONS is unset'
        When call validate_github_actions_env
        The status should be failure
      End

      It 'returns failure when GITHUB_ACTIONS is empty'
        export GITHUB_ACTIONS=""
        When call validate_github_actions_env
        The status should be failure
      End
    End
  End

  Describe 'validate_github_hosted_runner()'
    BeforeEach 'cleanup_runner_environment'
    AfterEach 'cleanup_runner_environment'

    cleanup_runner_environment() {
      unset RUNNER_ENVIRONMENT
    }

    Context 'valid runner environment'
      It 'returns success when RUNNER_ENVIRONMENT=github-hosted'
        export RUNNER_ENVIRONMENT="github-hosted"
        When call validate_github_hosted_runner
        The status should be success
      End
    End

    Context 'invalid runner environment'
      It 'returns failure when RUNNER_ENVIRONMENT=self-hosted'
        export RUNNER_ENVIRONMENT="self-hosted"
        When call validate_github_hosted_runner
        The status should be failure
      End

      It 'returns failure when RUNNER_ENVIRONMENT is unset'
        When call validate_github_hosted_runner
        The status should be failure
      End

      It 'returns failure when RUNNER_ENVIRONMENT is empty'
        export RUNNER_ENVIRONMENT=""
        When call validate_github_hosted_runner
        The status should be failure
      End
    End
  End

  Describe 'validate_runtime_variables()'
    BeforeEach 'cleanup_runtime_vars'
    AfterEach 'cleanup_runtime_vars'

    cleanup_runtime_vars() {
      unset RUNNER_TEMP GITHUB_OUTPUT GITHUB_PATH
    }

    Context 'all required variables set'
      BeforeEach 'setup_all_runtime_vars'

      setup_all_runtime_vars() {
        export RUNNER_TEMP="/tmp/runner"
        export GITHUB_OUTPUT="/tmp/output"
        export GITHUB_PATH="/tmp/path"
      }

      It 'returns success when all variables present'
        When call validate_runtime_variables
        The status should be success
      End
    End

    Context 'missing required variables'
      It 'returns failure when RUNNER_TEMP missing'
        export GITHUB_OUTPUT="/tmp/output"
        export GITHUB_PATH="/tmp/path"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when GITHUB_OUTPUT missing'
        export RUNNER_TEMP="/tmp/runner"
        export GITHUB_PATH="/tmp/path"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when GITHUB_PATH missing'
        export RUNNER_TEMP="/tmp/runner"
        export GITHUB_OUTPUT="/tmp/output"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when multiple variables missing'
        export RUNNER_TEMP="/tmp/runner"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when all variables missing'
        When call validate_runtime_variables
        The status should be failure
      End
    End
  End
End
