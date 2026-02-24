#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - Permissions Validation'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Helper Functions Tests
  # ============================================================================

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

    Context 'with expected value'
      BeforeEach 'setup_value_test'
      AfterEach 'cleanup_value_test'

      setup_value_test() {
        export TEST_VAR="expected_value"
      }

      cleanup_value_test() {
        unset TEST_VAR
      }

      It 'returns success when value matches'
        When call check_env_var "TEST_VAR" "expected_value"
        The status should be success
      End

      It 'returns failure when value does not match'
        When call check_env_var "TEST_VAR" "wrong_value"
        The status should be failure
      End
    End

    Context 'edge cases'
      AfterEach 'cleanup_edge_case_var'

      cleanup_edge_case_var() {
        unset TEST_VAR
      }

      It 'returns success when variable has whitespace-only value'
        export TEST_VAR="   "
        When call check_env_var "TEST_VAR"
        The status should be success
      End

      It 'returns failure when variable is set to empty string'
        export TEST_VAR=""
        When call check_env_var "TEST_VAR"
        The status should be failure
      End
    End
  End

  # ============================================================================
  # Command Availability Tests
  # ============================================================================

  Describe 'check_curl()'
    Context 'when curl is available'
      It 'returns success'
        When call check_curl
        The status should be success
      End

      It 'outputs nothing to stderr'
        When call check_curl
        The stderr should be blank
      End
    End

    Context 'when curl is not available'
      setup_no_curl() {
        RM_CMD=$(command -v rm)
        EMPTY_DIR=$(mktemp -d)
        SAVED_PATH="$PATH"
        PATH="$EMPTY_DIR"
      }
      teardown_no_curl() {
        PATH="$SAVED_PATH"
        "$RM_CMD" -rf "$EMPTY_DIR"
      }
      BeforeEach 'setup_no_curl'
      AfterEach 'teardown_no_curl'

      It 'returns failure'
        When call check_curl
        The status should be failure
      End

      It 'outputs nothing to stderr'
        When call check_curl
        The status should be failure
        The stderr should be blank
      End
    End
  End

  # ============================================================================
  # Token Check Tests
  # ============================================================================

  Describe 'check_github_token()'
    BeforeEach 'cleanup_check_github_token'
    AfterEach 'cleanup_check_github_token'

    cleanup_check_github_token() {
      unset GITHUB_TOKEN GITHUB_OUTPUT
    }

    Context 'token is set'
      It 'returns success and outputs progress'
        export GITHUB_TOKEN="ghp_test_token"
        When call check_github_token
        The status should be success
        The output should include "✓ GITHUB_TOKEN is set"
      End
    End

    Context 'token is not set'
      It 'returns failure with error message'
        When call check_github_token
        The status should be failure
        The output should include "Checking GITHUB_TOKEN"
        The stderr should include "GITHUB_TOKEN environment variable is not set"
      End
    End

    Context 'token is empty string'
      It 'returns failure'
        export GITHUB_TOKEN=""
        When call check_github_token
        The status should be failure
        The output should include "Checking GITHUB_TOKEN"
        The stderr should include "GITHUB_TOKEN environment variable is not set"
      End
    End

    Context 'token is whitespace-only'
      It 'returns success (non-empty check passes)'
        export GITHUB_TOKEN="   "
        When call check_github_token
        The status should be success
        The output should include "✓ GITHUB_TOKEN is set"
      End
    End

    Context 'classic PAT token via github-token input (ghp_ prefix)'
      It 'returns success'
        export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
        When call check_github_token
        The status should be success
        The output should include "✓ GITHUB_TOKEN is set"
      End
    End

    Context 'fine-grained PAT token via github-token input (github_pat_ prefix)'
      It 'returns success'
        export GITHUB_TOKEN="github_pat_xxxxxxxxxxxxxxxxxxxx"
        When call check_github_token
        The status should be success
        The output should include "✓ GITHUB_TOKEN is set"
      End
    End
  End

  # ============================================================================
  # Base Branch Resolution Tests
  # ============================================================================

  Describe 'determine_base_branch()'
    BeforeEach 'cleanup_base_branch_vars'
    AfterEach 'cleanup_base_branch_vars'

    cleanup_base_branch_vars() {
      unset GITHUB_BASE_REF GITHUB_REF_NAME
    }

    Context 'GITHUB_BASE_REF is set'
      It 'returns GITHUB_BASE_REF'
        export GITHUB_BASE_REF="main"
        export GITHUB_REF_NAME="feature-branch"
        When call determine_base_branch
        The output should eq "main"
        The status should be success
      End
    End

    Context 'GITHUB_BASE_REF not set, GITHUB_REF_NAME is set'
      It 'returns GITHUB_REF_NAME as fallback'
        export GITHUB_REF_NAME="develop"
        When call determine_base_branch
        The output should eq "develop"
        The status should be success
      End
    End

    Context 'neither GITHUB_BASE_REF nor GITHUB_REF_NAME is set'
      It 'returns failure'
        When call determine_base_branch
        The status should be failure
        The stderr should be blank
      End
    End
  End

  # ============================================================================
  # OIDC Permissions Tests (for reusability, not used by this action)
  # ============================================================================

  Describe 'validate_id_token_permissions()'
    BeforeEach 'cleanup_oidc_vars'
    AfterEach 'cleanup_oidc_vars'

    cleanup_oidc_vars() {
      unset ACTIONS_ID_TOKEN_REQUEST_URL
      unset ACTIONS_ID_TOKEN_REQUEST_TOKEN
    }

    Context 'valid OIDC permissions'
      It 'returns SUCCESS status when both OIDC variables are set'
        export ACTIONS_ID_TOKEN_REQUEST_URL="https://vstoken.actions.githubusercontent.com/test"
        export ACTIONS_ID_TOKEN_REQUEST_TOKEN="test_token_value"
        When call validate_id_token_permissions
        The status should be success
        The output should eq "SUCCESS:OIDC permissions validated"
      End
    End

    Context 'invalid OIDC permissions'
      It 'returns ERROR status when REQUEST_URL is not set'
        When call validate_id_token_permissions
        The status should be failure
        The output should eq "ERROR:ACTIONS_ID_TOKEN_REQUEST_URL not set"
      End

      It 'returns ERROR status when REQUEST_TOKEN is not set'
        export ACTIONS_ID_TOKEN_REQUEST_URL="https://vstoken.actions.githubusercontent.com/test"
        When call validate_id_token_permissions
        The status should be failure
        The output should eq "ERROR:ACTIONS_ID_TOKEN_REQUEST_TOKEN not set"
      End

      It 'returns ERROR status when REQUEST_URL is empty'
        export ACTIONS_ID_TOKEN_REQUEST_URL=""
        When call validate_id_token_permissions
        The status should be failure
        The output should eq "ERROR:ACTIONS_ID_TOKEN_REQUEST_URL not set"
      End

      It 'returns ERROR status when REQUEST_TOKEN is empty'
        export ACTIONS_ID_TOKEN_REQUEST_URL="https://vstoken.actions.githubusercontent.com/test"
        export ACTIONS_ID_TOKEN_REQUEST_TOKEN=""
        When call validate_id_token_permissions
        The status should be failure
        The output should eq "ERROR:ACTIONS_ID_TOKEN_REQUEST_TOKEN not set"
      End
    End
  End

  # ============================================================================
  # GitHub API POST Tests
  # ============================================================================

  Describe 'github_api_post()'
    BeforeEach 'setup_api_post_tests'
    AfterEach 'cleanup_api_post_tests'

    setup_api_post_tests() {
      export GITHUB_TOKEN="ghp_test_token"
      export GITHUB_REPOSITORY="owner/repo"
    }

    cleanup_api_post_tests() {
      unset GITHUB_TOKEN GITHUB_REPOSITORY
    }

    Context 'permission granted (422 - invalid payload but accepted)'
      BeforeEach 'mock_curl_422'

      mock_curl_422() {
        curl() { echo -n "422"; return 0; }
        export -f curl
      }

      It 'outputs HTTP 422 status code'
        When call github_api_post "/repos/owner/repo/git/refs" '{"ref":"refs/heads/test","sha":"0000"}'
        The output should eq "422"
        The status should be success
      End
    End

    Context 'permission denied (403)'
      BeforeEach 'mock_curl_403'

      mock_curl_403() {
        curl() { echo -n "403"; return 0; }
        export -f curl
      }

      It 'outputs HTTP 403 status code'
        When call github_api_post "/repos/owner/repo/git/refs" '{"ref":"refs/heads/test","sha":"0000"}'
        The output should eq "403"
        The status should be success
      End
    End

    Context 'authentication failure (401)'
      BeforeEach 'mock_curl_401'

      mock_curl_401() {
        curl() { echo -n "401"; return 0; }
        export -f curl
      }

      It 'outputs HTTP 401 status code'
        When call github_api_post "/repos/owner/repo/git/refs" '{"ref":"refs/heads/test","sha":"0000"}'
        The output should eq "401"
        The status should be success
      End
    End
  End

  # ============================================================================
  # Permission Probe Tests
  # ============================================================================

  Describe 'probe_github_write_permission()'
    BeforeEach 'setup_probe_tests'
    AfterEach 'cleanup_probe_tests'

    setup_probe_tests() {
      export GITHUB_TOKEN="ghp_test_token"
      export GITHUB_REPOSITORY="owner/repo"
      export GITHUB_BASE_REF="main"
    }

    cleanup_probe_tests() {
      unset GITHUB_TOKEN GITHUB_REPOSITORY GITHUB_BASE_REF
    }

    Context 'commit operation - permission granted (422)'
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

    Context 'commit operation - permission granted (201)'
      BeforeEach 'mock_api_post_201'

      mock_api_post_201() {
        github_api_post() { echo "201"; }
        export -f github_api_post
      }

      It 'returns success'
        When call probe_github_write_permission "commit"
        The status should be success
      End
    End

    Context 'commit operation - permission denied (403)'
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

    Context 'pr operation - permission granted (422)'
      BeforeEach 'mock_pr_probe_success'

      mock_pr_probe_success() {
        github_api_post() { echo "422"; }
        export -f github_api_post
      }

      It 'returns success'
        When call probe_github_write_permission "pr"
        The status should be success
      End
    End

    Context 'pr operation - permission denied (403)'
      BeforeEach 'mock_pr_probe_denied'

      mock_pr_probe_denied() {
        github_api_post() { echo "403"; }
        export -f github_api_post
      }

      It 'returns failure'
        When call probe_github_write_permission "pr"
        The status should be failure
        The stderr should include "Permission denied (403)"
      End
    End

    Context 'pr operation - no base branch available'
      BeforeEach 'setup_pr_no_base_branch'

      setup_pr_no_base_branch() {
        unset GITHUB_BASE_REF GITHUB_REF_NAME
      }

      It 'returns failure with descriptive error'
        When call probe_github_write_permission "pr"
        The status should be failure
        The stderr should include "GITHUB_BASE_REF"
      End
    End

    Context 'authentication failure (401)'
      BeforeEach 'mock_api_post_401'

      mock_api_post_401() {
        github_api_post() { echo "401"; }
        export -f github_api_post
      }

      It 'returns failure with authentication error'
        When call probe_github_write_permission "commit"
        The status should be failure
        The stderr should include "Authentication failed"
      End
    End

    Context 'unexpected HTTP response'
      BeforeEach 'mock_api_post_500'

      mock_api_post_500() {
        github_api_post() { echo "500"; }
        export -f github_api_post
      }

      It 'returns failure with error message'
        When call probe_github_write_permission "commit"
        The status should be failure
        The stderr should include "Unexpected HTTP response"
      End
    End

    Context 'unknown operation'
      It 'returns failure with unknown operation error'
        When call probe_github_write_permission "unknown"
        The status should be failure
        The stderr should include "Unknown operation"
      End
    End
  End

End
