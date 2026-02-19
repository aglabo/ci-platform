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
  # GitHub Token Tests
  # ============================================================================

  Describe 'validate_github_token()'
    BeforeEach 'cleanup_github_token'
    AfterEach 'cleanup_github_token'

    cleanup_github_token() {
      unset GITHUB_TOKEN
    }

    Context 'valid token'
      It 'returns SUCCESS status when GITHUB_TOKEN is set'
        export GITHUB_TOKEN="ghp_test_token_value"
        When call validate_github_token
        The status should be success
        The output should eq "SUCCESS:GITHUB_TOKEN is set"
      End
    End

    Context 'invalid token'
      It 'returns ERROR status when GITHUB_TOKEN is not set'
        When call validate_github_token
        The status should be failure
        The output should eq "ERROR:GITHUB_TOKEN environment variable is not set"
      End

      It 'returns ERROR status when GITHUB_TOKEN is empty'
        export GITHUB_TOKEN=""
        When call validate_github_token
        The status should be failure
        The output should eq "ERROR:GITHUB_TOKEN environment variable is not set"
      End
    End

    Context 'edge cases'
      It 'returns SUCCESS when GITHUB_TOKEN has whitespace-only value'
        export GITHUB_TOKEN="   "
        When call validate_github_token
        The status should be success
        The output should eq "SUCCESS:GITHUB_TOKEN is set"
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
  # Token Scopes Parsing Tests
  # ============================================================================

  Describe 'parse_oauth_scopes()'
    BeforeEach 'setup_token_scopes'
    AfterEach 'cleanup_token_scopes'

    setup_token_scopes() {
      TOKEN_SCOPES=""
      TEST_HEADER_FILE=$(mktemp)
    }

    cleanup_token_scopes() {
      unset TOKEN_SCOPES
      rm -f "$TEST_HEADER_FILE"
    }

    Context 'valid header file'
      It 'extracts scopes from X-OAuth-Scopes header'
        echo "HTTP/1.1 200 OK" > "$TEST_HEADER_FILE"
        echo "X-OAuth-Scopes: repo, user, gist" >> "$TEST_HEADER_FILE"
        echo "" >> "$TEST_HEADER_FILE"
        When call parse_oauth_scopes "$TEST_HEADER_FILE"
        The status should be success
        The variable TOKEN_SCOPES should eq "repo user gist"
      End

      It 'handles empty scopes'
        echo "HTTP/1.1 200 OK" > "$TEST_HEADER_FILE"
        echo "X-OAuth-Scopes: " >> "$TEST_HEADER_FILE"
        echo "" >> "$TEST_HEADER_FILE"
        When call parse_oauth_scopes "$TEST_HEADER_FILE"
        The status should be success
        The variable TOKEN_SCOPES should eq ""
      End

      It 'extracts single scope without comma'
        echo "HTTP/1.1 200 OK" > "$TEST_HEADER_FILE"
        echo "X-OAuth-Scopes: repo" >> "$TEST_HEADER_FILE"
        When call parse_oauth_scopes "$TEST_HEADER_FILE"
        The status should be success
        The variable TOKEN_SCOPES should eq "repo"
      End

      It 'matches header name case-insensitively'
        echo "HTTP/1.1 200 OK" > "$TEST_HEADER_FILE"
        echo "x-oauth-scopes: repo, user" >> "$TEST_HEADER_FILE"
        When call parse_oauth_scopes "$TEST_HEADER_FILE"
        The status should be success
        The variable TOKEN_SCOPES should eq "repo user"
      End
    End

    Context 'invalid header file'
      It 'returns failure when header not found'
        echo "HTTP/1.1 200 OK" > "$TEST_HEADER_FILE"
        echo "Content-Type: application/json" >> "$TEST_HEADER_FILE"
        When call parse_oauth_scopes "$TEST_HEADER_FILE"
        The status should be failure
      End

      It 'returns failure when file does not exist'
        When call parse_oauth_scopes "/nonexistent/file"
        The status should be failure
      End
    End
  End

  # ============================================================================
  # Required Scopes Checking Tests
  # ============================================================================

  Describe 'check_required_scopes()'
    BeforeEach 'setup_scope_checking'
    AfterEach 'cleanup_scope_checking'

    setup_scope_checking() {
      TOKEN_SCOPES=""
      MISSING_SCOPES=""
    }

    cleanup_scope_checking() {
      unset TOKEN_SCOPES
      unset MISSING_SCOPES
    }

    Context 'all scopes present'
      It 'returns success when all required scopes exist'
        TOKEN_SCOPES="repo user gist admin:org"
        When call check_required_scopes "repo" "user"
        The status should be success
        The variable MISSING_SCOPES should eq ""
      End

      It 'validates single scope'
        TOKEN_SCOPES="repo"
        When call check_required_scopes "repo"
        The status should be success
        The variable MISSING_SCOPES should eq ""
      End

      It 'returns success when no scopes are required'
        TOKEN_SCOPES="repo"
        When call check_required_scopes
        The status should be success
        The variable MISSING_SCOPES should eq ""
      End
    End

    Context 'scopes missing'
      It 'returns failure and sets MISSING_SCOPES'
        TOKEN_SCOPES="repo user"
        When call check_required_scopes "repo" "admin:org" "gist"
        The status should be failure
        The variable MISSING_SCOPES should eq "admin:org gist"
      End

      It 'handles empty TOKEN_SCOPES'
        TOKEN_SCOPES=""
        When call check_required_scopes "repo" "user"
        The status should be failure
        The variable MISSING_SCOPES should eq "repo user"
      End

      It 'does not match scope as substring of another scope'
        TOKEN_SCOPES="admin:repo"
        When call check_required_scopes "repo"
        The status should be failure
        The variable MISSING_SCOPES should eq "repo"
      End
    End
  End

  # ============================================================================
  # GitHub API Call Tests
  # ============================================================================

  Describe 'call_github_api()'
    BeforeEach 'setup_api_tests'
    AfterEach 'cleanup_api_tests'

    setup_api_tests() {
      export GITHUB_TOKEN="ghp_test_token"
      TEST_OUTPUT_FILE=$(mktemp)
    }

    cleanup_api_tests() {
      unset GITHUB_TOKEN
      rm -f "$TEST_OUTPUT_FILE"
    }

    Context 'successful API call'
      BeforeEach 'setup_successful_curl'

      setup_successful_curl() {
        curl() {
          # Mock successful curl response to stdout (will be redirected by caller)
          echo "HTTP/1.1 200 OK"
          echo "X-OAuth-Scopes: repo"
          return 0
        }
        export -f curl
      }

      It 'returns success and writes to output file'
        When call call_github_api "/" "$TEST_OUTPUT_FILE"
        The status should be success
        The contents of file "$TEST_OUTPUT_FILE" should include "HTTP/1.1 200 OK"
      End

      It 'uses default endpoint when endpoint argument is empty'
        When call call_github_api "" "$TEST_OUTPUT_FILE"
        The status should be success
      End
    End

    Context 'failed API call'
      BeforeEach 'setup_failed_curl'

      setup_failed_curl() {
        curl() { return 1; }
        export -f curl
      }

      It 'returns failure'
        When call call_github_api "/" "$TEST_OUTPUT_FILE"
        The status should be failure
      End
    End
  End

End
