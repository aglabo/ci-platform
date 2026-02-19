#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - probe_github_write_permission() Functional'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Permission Probe Functional Tests
  # ============================================================================

  Describe 'probe_github_write_permission()'
    BeforeEach 'setup_probe_tests'
    AfterEach 'cleanup_probe_tests'

    setup_probe_tests() {
      export GITHUB_TOKEN="ghp_test_token"
      export GITHUB_REPOSITORY="owner/repo"
      export GITHUB_REF_NAME="main"
    }

    cleanup_probe_tests() {
      unset GITHUB_TOKEN GITHUB_REPOSITORY GITHUB_REF_NAME
    }

    Context 'commit probe - API returns 422 (permission granted)'
      BeforeEach 'mock_api_post_422'

      mock_api_post_422() {
        github_api_post() { echo "422"; }
        export -f github_api_post
      }

      It 'returns success'
        When call probe_github_write_permission "commit"
        The status should be success
      End
    End

    Context 'commit probe - API returns 403 (permission denied)'
      BeforeEach 'mock_api_post_403'

      mock_api_post_403() {
        github_api_post() { echo "403"; }
        export -f github_api_post
      }

      It 'returns failure'
        When call probe_github_write_permission "commit"
        The status should be failure
        The stderr should include "Permission denied (403)"
      End
    End

    Context 'commit probe - API returns 409 (conflict but permission granted)'
      BeforeEach 'mock_api_post_409'

      mock_api_post_409() {
        github_api_post() { echo "409"; }
        export -f github_api_post
      }

      It 'returns success'
        When call probe_github_write_permission "commit"
        The status should be success
      End
    End

    Context 'pr probe - API returns 422 (permission granted)'
      BeforeEach 'mock_pr_success'

      mock_pr_success() {
        github_api_post() { echo "422"; }
        get_default_branch() { echo "main"; }
        export -f github_api_post get_default_branch
      }

      It 'returns success'
        When call probe_github_write_permission "pr"
        The status should be success
      End
    End

    Context 'pr probe - API returns 403 (permission denied)'
      BeforeEach 'mock_pr_denied'

      mock_pr_denied() {
        github_api_post() { echo "403"; }
        get_default_branch() { echo "main"; }
        export -f github_api_post get_default_branch
      }

      It 'returns failure'
        When call probe_github_write_permission "pr"
        The status should be failure
        The stderr should include "Permission denied (403)"
      End
    End

    Context 'authentication failure (401)'
      BeforeEach 'mock_api_post_401'

      mock_api_post_401() {
        github_api_post() { echo "401"; }
        export -f github_api_post
      }

      It 'returns failure'
        When call probe_github_write_permission "commit"
        The status should be failure
        The stderr should include "Authentication failed"
      End

      It 'outputs authentication error to stderr'
        When call probe_github_write_permission "commit"
        The status should be failure
        The stderr should include "Authentication failed"
      End
    End

    Context 'unknown operation'
      It 'returns failure'
        When call probe_github_write_permission "delete"
        The status should be failure
        The stderr should include "Unknown operation"
      End

      It 'outputs unknown operation error to stderr'
        When call probe_github_write_permission "delete"
        The status should be failure
        The stderr should include "Unknown operation"
      End
    End
  End
End
