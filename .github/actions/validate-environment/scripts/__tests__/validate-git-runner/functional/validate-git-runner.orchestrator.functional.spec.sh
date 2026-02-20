#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Orchestrator Functional'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  Include "$SCRIPT_PATH"

  # ============================================================================
  # Base setup: valid Linux/amd64 GitHub Actions environment
  # Each Context adds/overrides only what it needs to test
  # ============================================================================

  BeforeEach 'setup_valid_env'
  AfterEach 'cleanup_env'

  setup_valid_env() {
    # Mock OS/arch detection to avoid real uname calls (runs on Windows in CI)
    detect_os() { echo "linux"; }
    detect_architecture() { echo "x86_64"; }
    export -f detect_os detect_architecture

    export GITHUB_ACTIONS="true"
    export RUNNER_ENVIRONMENT="self-hosted"
    export RUNNER_TEMP="/tmp"
    export GITHUB_OUTPUT="/dev/null"
    export GITHUB_PATH="/usr/local/bin"

    EXPECTED_ARCH="amd64"
    REQUIRE_GITHUB_HOSTED="false"
    NORMALIZED_ARCH=""
    DETECTED_OS=""
    DETECTED_ARCH=""
  }

  cleanup_env() {
    unset GITHUB_ACTIONS RUNNER_ENVIRONMENT RUNNER_TEMP GITHUB_OUTPUT GITHUB_PATH
    EXPECTED_ARCH="amd64"
    REQUIRE_GITHUB_HOSTED="false"
    NORMALIZED_ARCH=""
    DETECTED_OS=""
    DETECTED_ARCH=""
  }

  # ============================================================================
  # 許容: self-hosted / larger / vendor 不問
  # ============================================================================

  Describe 'validate_git_runner()'
    Context 'require-git-hosted=false (default): self-hosted runner is allowed'
      BeforeEach 'setup_self_hosted_default'

      setup_self_hosted_default() {
        REQUIRE_GITHUB_HOSTED="false"
        export RUNNER_ENVIRONMENT="self-hosted"
      }

      It 'returns success for self-hosted runner'
        When call validate_git_runner
        The status should be success
        The output should be present
        The stderr should be blank
      End

      It 'outputs validation passed message'
        When call validate_git_runner
        The status should be success
        The output should include "GitHub runner validation passed"
        The stderr should be blank
      End
    End

    Context 'require-git-hosted=false (default): RUNNER_ENVIRONMENT unset is allowed'
      BeforeEach 'setup_runner_env_unset'

      setup_runner_env_unset() {
        REQUIRE_GITHUB_HOSTED="false"
        unset RUNNER_ENVIRONMENT
      }

      It 'returns success when RUNNER_ENVIRONMENT is not set'
        When call validate_git_runner
        The status should be success
        The output should be present
        The stderr should be blank
      End
    End

    Context 'require-git-hosted=true: github-hosted runner passes'
      BeforeEach 'setup_github_hosted_required'

      setup_github_hosted_required() {
        REQUIRE_GITHUB_HOSTED="true"
        export RUNNER_ENVIRONMENT="github-hosted"
      }

      It 'returns success for github-hosted runner'
        When call validate_git_runner
        The status should be success
        The output should be present
        The stderr should be blank
      End

      It 'outputs RUNNER_ENVIRONMENT confirmation'
        When call validate_git_runner
        The status should be success
        The output should include "github-hosted"
        The stderr should be blank
      End
    End

    # ============================================================================
    # 強制 fail 条件
    # ============================================================================

    Context 'fail: require-git-hosted=true with self-hosted runner'
      BeforeEach 'setup_self_hosted_required'

      setup_self_hosted_required() {
        REQUIRE_GITHUB_HOSTED="true"
        export RUNNER_ENVIRONMENT="self-hosted"
      }

      It 'returns failure for self-hosted runner'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs GitHub-hosted runner error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "GitHub-hosted runner"
        The output should be present
      End
    End

    Context 'fail: OS != Linux'
      BeforeEach 'setup_non_linux'

      setup_non_linux() {
        detect_os() { echo "darwin"; }
        export -f detect_os
      }

      It 'returns failure for non-Linux OS'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs Linux requirement error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "Linux"
        The output should be present
      End
    End

    Context 'fail: arch unsupported'
      BeforeEach 'setup_unsupported_arch'

      setup_unsupported_arch() {
        detect_architecture() { echo "mips"; }
        export -f detect_architecture
      }

      It 'returns failure for unsupported architecture'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs unsupported architecture error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "Unsupported architecture"
        The output should be present
      End
    End

    Context 'fail: arch mismatch'
      BeforeEach 'setup_arch_mismatch'

      setup_arch_mismatch() {
        EXPECTED_ARCH="arm64"
        detect_architecture() { echo "x86_64"; }
        export -f detect_architecture
      }

      It 'returns failure on architecture mismatch'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs architecture mismatch error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "mismatch"
        The output should be present
      End
    End

    Context 'fail: GITHUB_ACTIONS != true'
      BeforeEach 'setup_no_github_actions'

      setup_no_github_actions() {
        export GITHUB_ACTIONS="false"
      }

      It 'returns failure when not in GitHub Actions environment'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs GitHub Actions environment error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "GitHub Actions"
        The output should be present
      End
    End

    Context 'fail: runtime variables missing (RUNNER_TEMP)'
      BeforeEach 'setup_missing_runner_temp'

      setup_missing_runner_temp() {
        unset RUNNER_TEMP
      }

      It 'returns failure when RUNNER_TEMP is missing'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End

      It 'outputs missing variables error to stderr'
        When call validate_git_runner
        The status should be failure
        The stderr should include "environment variables"
        The output should be present
      End
    End

    Context 'fail: runtime variables missing (GITHUB_PATH)'
      BeforeEach 'setup_missing_github_path'

      setup_missing_github_path() {
        unset GITHUB_PATH
      }

      It 'returns failure when GITHUB_PATH is missing'
        When call validate_git_runner
        The status should be failure
        The output should be present
        The stderr should be present
      End
    End
  End
End
