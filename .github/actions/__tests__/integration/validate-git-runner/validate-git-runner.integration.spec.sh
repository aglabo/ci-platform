#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/__tests__/integration/validate-git-runner.integration.spec.sh
# @(#) : Integration tests for GitHub environment validation in validate-git-runner.sh

Describe 'validate-git-runner.sh - GitHub Environment Integration'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-git-runner.sh"

  # ============================================================================
  # validate_github_actions_env()
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

      It 'returns failure when GITHUB_ACTIONS is uppercase TRUE'
        export GITHUB_ACTIONS="TRUE"
        When call validate_github_actions_env
        The status should be failure
      End
    End
  End

  # ============================================================================
  # validate_github_hosted_runner()
  # ============================================================================

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

      It 'returns failure when RUNNER_ENVIRONMENT is uppercase GITHUB-HOSTED'
        export RUNNER_ENVIRONMENT="GITHUB-HOSTED"
        When call validate_github_hosted_runner
        The status should be failure
      End
    End
  End

  # ============================================================================
  # validate_runtime_variables()
  # ============================================================================

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

    Context 'variables set to empty string'
      It 'returns failure when RUNNER_TEMP is empty string'
        export RUNNER_TEMP=""
        export GITHUB_OUTPUT="/tmp/output"
        export GITHUB_PATH="/tmp/path"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when GITHUB_OUTPUT is empty string'
        export RUNNER_TEMP="/tmp/runner"
        export GITHUB_OUTPUT=""
        export GITHUB_PATH="/tmp/path"
        When call validate_runtime_variables
        The status should be failure
      End

      It 'returns failure when GITHUB_PATH is empty string'
        export RUNNER_TEMP="/tmp/runner"
        export GITHUB_OUTPUT="/tmp/output"
        export GITHUB_PATH=""
        When call validate_runtime_variables
        The status should be failure
      End
    End
  End
End
