#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/__tests__/e2e/validate-git-runner.e2e.spec.sh
# @(#) : E2E tests for validate_git_runner() - end-user facing orchestrator

Describe 'validate_git_runner() - E2E'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-git-runner.sh"

  BeforeEach 'setup_test'
  AfterEach 'cleanup_test'

  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
    export EXPECTED_ARCHITECTURE="amd64"
    EXPECTED_ARCH="amd64"
  }

  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
    unset GITHUB_ACTIONS RUNNER_ENVIRONMENT RUNNER_TEMP GITHUB_PATH
    unset EXPECTED_ARCHITECTURE
  }

  # ============================================================================
  # Success cases
  # ============================================================================

  Describe 'success cases'
    BeforeEach 'setup_github_env'

    setup_github_env() {
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="github-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
    }

    It 'returns success with valid GitHub-hosted Linux environment'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      When call validate_git_runner
      The status should be success
      The output should include "GitHub runner validation passed"
    End

    It 'writes status=success to GITHUB_OUTPUT'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      check_output_status() {
        validate_git_runner
        grep "status=" "$GITHUB_OUTPUT_FILE" | tr -d '\r'
      }
      When call check_output_status
      The output should include "status=success"
    End
  End

  # ============================================================================
  # Failure cases
  # ============================================================================

  Describe 'failure cases'
    It 'returns failure on non-Linux OS'
      uname() {
        case "$1" in
          -s) echo "Darwin" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      When call validate_git_runner
      The status should be failure
      The stderr should include "This action requires Linux"
      The output should be present
    End

    It 'returns failure when not in GitHub Actions'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      export RUNNER_ENVIRONMENT="github-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
      When call validate_git_runner
      The status should be failure
      The stderr should include "Not running in GitHub Actions environment"
      The output should be present
    End

    It 'returns failure with self-hosted runner'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="self-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
      When call validate_git_runner
      The status should be failure
      The stderr should include "GitHub-hosted runner"
      The output should be present
    End

    It 'writes status=error to GITHUB_OUTPUT on failure'
      uname() {
        case "$1" in
          -s) echo "Darwin" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      check_output_status() {
        validate_git_runner || true
        grep "status=" "$GITHUB_OUTPUT_FILE" | tr -d '\r'
      }
      When call check_output_status
      The output should include "status=error"
      The stderr should not be blank
    End

    It 'returns failure when EXPECTED_ARCH is invalid'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="github-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
      EXPECTED_ARCH="invalid"
      When call validate_git_runner
      The status should be failure
      The stderr should include "Invalid architecture input"
      The output should be present
    End

    It 'returns failure when architecture does not match expected'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="github-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
      EXPECTED_ARCH="arm64"
      When call validate_git_runner
      The status should be failure
      The stderr should include "Architecture mismatch"
      The output should be present
    End

    It 'returns failure when RUNNER_TEMP is unset'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "x86_64" ;;
          *)  command uname "$@" ;;
        esac
      }
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="github-hosted"
      export GITHUB_PATH="/tmp/path"
      When call validate_git_runner
      The status should be failure
      The stderr should include "Required environment variables are not set"
      The output should be present
    End

    It 'returns failure when detected architecture is unsupported'
      uname() {
        case "$1" in
          -s) echo "Linux" ;;
          -m) echo "mips" ;;
          *)  command uname "$@" ;;
        esac
      }
      export GITHUB_ACTIONS="true"
      export RUNNER_ENVIRONMENT="github-hosted"
      export RUNNER_TEMP="/tmp/runner"
      export GITHUB_PATH="/tmp/path"
      When call validate_git_runner
      The status should be failure
      The stderr should include "Unsupported architecture"
      The output should be present
    End
  End
End
