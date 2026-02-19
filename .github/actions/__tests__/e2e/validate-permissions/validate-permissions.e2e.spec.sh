#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-permissions.sh - User-Facing Success Scenarios (E2E)'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-permissions.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # Main Orchestrator Success Path Tests
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

    Context 'ACTIONS_TYPE=pr with valid permissions'
      It 'validates successfully'
        export ACTIONS_TYPE="pr"
        When run validate_permissions
        The status should be success
        The output should include "PR operations permissions validated"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=GitHub permissions validated"
      End
    End

    Context 'ACTIONS_TYPE=commit with valid permissions'
      It 'validates successfully'
        export ACTIONS_TYPE="commit"
        When run validate_permissions
        The status should be success
        The output should include "Commit operations permissions validated"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
      End
    End

    Context 'ACTIONS_TYPE=read'
      It 'validates successfully without API call'
        export ACTIONS_TYPE="read"
        When run validate_permissions
        The status should be success
        The output should include "contents: read is a required permission"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
      End
    End

    Context 'ACTIONS_TYPE unknown value'
      It 'fails with error for invalid type'
        export ACTIONS_TYPE="unknown"
        When run validate_permissions
        The status should be failure
        The stderr should include "Invalid actions-type"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
      End
    End
  End
End
