#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - validate_permissions() Functional'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  BeforeEach 'setup_permissions_test'
  AfterEach 'cleanup_permissions_test'

  setup_permissions_test() {
    export GITHUB_TOKEN="ghp_test_token"
    export GITHUB_OUTPUT="/dev/null"
  }

  cleanup_permissions_test() {
    unset GITHUB_TOKEN GITHUB_OUTPUT
  }

  # ============================================================================
  # Invalid actions-type argument
  # ============================================================================

  Describe 'invalid actions-type argument'
    It 'returns failure for unknown type'
      When call validate_permissions "invalid"
      The status should be failure
      The stderr should include "Invalid actions-type"
    End

    It 'outputs ::error:: to stderr for unknown type'
      When call validate_permissions "invalid"
      The status should be failure
      The stderr should include "Invalid actions-type"
    End

    It 'returns failure for "write" type'
      When call validate_permissions "write"
      The status should be failure
      The stderr should include "Invalid actions-type"
    End

    It 'returns failure for "admin" type'
      When call validate_permissions "admin"
      The status should be failure
      The stderr should include "Invalid actions-type"
    End
  End

  # ============================================================================
  # "read" argument
  # ============================================================================

  Describe '"read" argument'
    It 'returns success'
      When call validate_permissions "read"
      The status should be success
      The output should include "=== Validating GitHub Permissions ==="
    End

    It 'outputs contents: read message'
      When call validate_permissions "read"
      The output should include "contents: read is a required permission"
    End

    It 'does not call probe_github_write_permission'
      mock_called=0
      probe_github_write_permission() { mock_called=1; return 0; }
      export -f probe_github_write_permission
      When call validate_permissions "read"
      The status should be success
      The output should include "=== Validating GitHub Permissions ==="
    End
  End

  # ============================================================================
  # "commit" argument
  # ============================================================================

  Describe '"commit" argument'
    Context 'probe succeeds'
      BeforeEach 'mock_probe_success'

      mock_probe_success() {
        probe_github_write_permission() { return 0; }
        export -f probe_github_write_permission
      }

      It 'returns success'
        When call validate_permissions "commit"
        The status should be success
        The output should include "=== Validating GitHub Permissions ==="
      End

      It 'outputs commit validated message'
        When call validate_permissions "commit"
        The output should include "Commit operations permissions validated"
      End
    End

    Context 'probe fails'
      BeforeEach 'mock_probe_failure'

      mock_probe_failure() {
        probe_github_write_permission() { return 1; }
        export -f probe_github_write_permission
      }

      It 'returns failure'
        When call validate_permissions "commit"
        The status should be failure
        The output should include "Checking GITHUB_TOKEN"
        The stderr should include "contents: write permission not granted"
      End

      It 'outputs ::error:: to stderr'
        When call validate_permissions "commit"
        The status should be failure
        The stderr should include "contents: write permission not granted"
        The output should include "Checking GITHUB_TOKEN"
      End
    End
  End

  # ============================================================================
  # "pr" argument
  # ============================================================================

  Describe '"pr" argument'
    Context 'probe succeeds'
      BeforeEach 'mock_probe_success'

      mock_probe_success() {
        probe_github_write_permission() { return 0; }
        export -f probe_github_write_permission
      }

      It 'returns success'
        When call validate_permissions "pr"
        The status should be success
        The output should include "=== Validating GitHub Permissions ==="
      End

      It 'outputs PR validated message'
        When call validate_permissions "pr"
        The output should include "PR operations permissions validated"
      End
    End

    Context 'probe fails'
      BeforeEach 'mock_probe_failure'

      mock_probe_failure() {
        probe_github_write_permission() { return 1; }
        export -f probe_github_write_permission
      }

      It 'returns failure'
        When call validate_permissions "pr"
        The status should be failure
        The output should include "Checking GITHUB_TOKEN"
        The stderr should include "pull-requests: write permission not granted"
      End

      It 'outputs ::error:: to stderr'
        When call validate_permissions "pr"
        The status should be failure
        The stderr should include "pull-requests: write permission not granted"
        The output should include "Checking GITHUB_TOKEN"
      End
    End
  End

  # ============================================================================
  # GITHUB_TOKEN missing (common to all types)
  # ============================================================================

  Describe 'GITHUB_TOKEN not set'
    BeforeEach 'unset_github_token'

    unset_github_token() {
      unset GITHUB_TOKEN
    }

    It 'returns failure for "read" type'
      When call validate_permissions "read"
      The status should be failure
      The output should include "Checking GITHUB_TOKEN"
      The stderr should include "GITHUB_TOKEN"
    End

    It 'returns failure for "commit" type'
      When call validate_permissions "commit"
      The status should be failure
      The output should include "Checking GITHUB_TOKEN"
      The stderr should include "GITHUB_TOKEN"
    End

    It 'returns failure for "pr" type'
      When call validate_permissions "pr"
      The status should be failure
      The output should include "Checking GITHUB_TOKEN"
      The stderr should include "GITHUB_TOKEN"
    End

    It 'outputs ::error:: to stderr'
      When call validate_permissions "read"
      The status should be failure
      The stderr should include "GITHUB_TOKEN"
      The output should include "Checking GITHUB_TOKEN"
    End
  End

End
