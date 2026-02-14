#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - Token Scopes Validation (Functional)'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Token Scopes Validation Tests
  # ============================================================================

  Describe 'validate_token_scopes()'
    BeforeEach 'setup_scopes_tests'
    AfterEach 'cleanup_scopes_tests'

    setup_scopes_tests() {
      export GITHUB_TOKEN="ghp_test_token"
      TOKEN_SCOPES=""
      MISSING_SCOPES=""
    }

    cleanup_scopes_tests() {
      unset GITHUB_TOKEN TOKEN_SCOPES MISSING_SCOPES
    }

    Context 'API call succeeds with required scopes'
      BeforeEach 'setup_successful_api'

      setup_successful_api() {
        call_github_api() {
          local output_file="$2"
          echo "HTTP/1.1 200 OK" > "$output_file"
          echo "X-OAuth-Scopes: repo user" >> "$output_file"
          return 0
        }
        export -f call_github_api
      }

      It 'returns SUCCESS status'
        When call validate_token_scopes "repo"
        The status should be success
        The output should eq "SUCCESS:All required scopes present"
        The variable TOKEN_SCOPES should eq "repo user"
      End
    End

    Context 'API call fails'
      BeforeEach 'setup_failed_api'

      setup_failed_api() {
        call_github_api() { return 1; }
        export -f call_github_api
      }

      It 'returns ERROR status for network failure'
        When call validate_token_scopes "repo"
        The status should be failure
        The output should eq "ERROR:GitHub API call failed"
      End
    End

    Context 'rate limit exceeded'
      BeforeEach 'setup_rate_limit_api'

      setup_rate_limit_api() {
        call_github_api() {
          echo "rate limit exceeded" > "$2"
          return 0
        }
        export -f call_github_api
      }

      It 'returns ERROR status for rate limit'
        When call validate_token_scopes "repo"
        The status should be failure
        The output should eq "ERROR:GitHub API rate limit exceeded"
      End
    End

    Context 'missing required scopes'
      BeforeEach 'setup_insufficient_scopes'

      setup_insufficient_scopes() {
        call_github_api() {
          local output_file="$2"
          echo "HTTP/1.1 200 OK" > "$output_file"
          echo "X-OAuth-Scopes: user" >> "$output_file"
          return 0
        }
        export -f call_github_api
      }

      It 'returns ERROR status with missing scopes'
        When call validate_token_scopes "repo"
        The status should be failure
        The output should eq "ERROR:Missing required scopes: repo"
        The variable MISSING_SCOPES should eq "repo"
      End
    End

    Context 'multiple missing scopes'
      BeforeEach 'setup_multiple_missing_scopes'

      setup_multiple_missing_scopes() {
        call_github_api() {
          local output_file="$2"
          echo "HTTP/1.1 200 OK" > "$output_file"
          echo "X-OAuth-Scopes: user" >> "$output_file"
          return 0
        }
        export -f call_github_api
      }

      It 'returns ERROR status with all missing scopes listed'
        When call validate_token_scopes "repo" "admin:org"
        The status should be failure
        The output should eq "ERROR:Missing required scopes: repo admin:org"
        The variable MISSING_SCOPES should eq "repo admin:org"
      End
    End

    Context 'parse failure'
      BeforeEach 'setup_no_scopes_header'

      setup_no_scopes_header() {
        call_github_api() {
          local output_file="$2"
          echo "HTTP/1.1 200 OK" > "$output_file"
          echo "Content-Type: application/json" >> "$output_file"
          return 0
        }
        export -f call_github_api
      }

      It 'returns ERROR when X-OAuth-Scopes header is missing'
        When call validate_token_scopes "repo"
        The status should be failure
        The output should eq "ERROR:Failed to parse token scopes from API response"
      End
    End
  End
End
