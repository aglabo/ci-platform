#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - Orchestrator Error Flows (Integration)'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Main Orchestrator Error Path Tests
  # ============================================================================

  Describe 'validate_permissions()'
    BeforeEach 'setup_orchestrator_test'
    AfterEach 'cleanup_orchestrator_test'

    setup_orchestrator_test() {
      GITHUB_OUTPUT_FILE=$(mktemp)
      export GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE"
      export GITHUB_TOKEN="ghp_test_token"

      # Mock call_github_api by default
      call_github_api() {
        echo "HTTP/1.1 200 OK" > "$2"
        echo "X-OAuth-Scopes: repo" >> "$2"
        return 0
      }
      export -f call_github_api
    }

    cleanup_orchestrator_test() {
      rm -f "$GITHUB_OUTPUT_FILE"
      unset GITHUB_OUTPUT GITHUB_TOKEN ACTIONS_TYPE
    }

    Context 'GITHUB_TOKEN not set'
      It 'fails with error in GITHUB_OUTPUT'
        unset GITHUB_TOKEN
        When run validate_permissions
        The status should be failure
        The stdout should include "Validating GitHub Permissions"
        The stderr should include "GITHUB_TOKEN environment variable is not set"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=GITHUB_TOKEN environment variable is not set"
      End
    End

    Context 'ACTIONS_TYPE=pr with insufficient permissions'
      BeforeEach 'setup_insufficient_pr_permissions'

      setup_insufficient_pr_permissions() {
        call_github_api() {
          echo "HTTP/1.1 200 OK" > "$2"
          echo "X-OAuth-Scopes: user" >> "$2"
          return 0
        }
        export -f call_github_api
      }

      It 'fails with error about missing scopes'
        export ACTIONS_TYPE="pr"
        When run validate_permissions
        The status should be failure
        The stdout should include "Validating GitHub Permissions"
        The stderr should include "Missing required scopes"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=Missing PR permissions"
      End
    End

    Context 'ACTIONS_TYPE=commit with insufficient permissions'
      BeforeEach 'setup_insufficient_commit_permissions'

      setup_insufficient_commit_permissions() {
        call_github_api() {
          echo "HTTP/1.1 200 OK" > "$2"
          echo "X-OAuth-Scopes: user" >> "$2"
          return 0
        }
        export -f call_github_api
      }

      It 'fails with error about missing scopes'
        export ACTIONS_TYPE="commit"
        When run validate_permissions
        The status should be failure
        The stdout should include "Validating GitHub Permissions"
        The stderr should include "Missing required scopes"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=Missing commit permissions"
      End
    End
  End
End
