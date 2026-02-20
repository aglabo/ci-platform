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
      export GITHUB_REPOSITORY="owner/repo"
      export GITHUB_REF_NAME="main"

      # Mock github_api_post by default (returns 422 - permission OK)
      github_api_post() { echo "422"; }
      export -f github_api_post
    }

    cleanup_orchestrator_test() {
      rm -f "$GITHUB_OUTPUT_FILE"
      unset GITHUB_OUTPUT GITHUB_TOKEN ACTIONS_TYPE GITHUB_REPOSITORY GITHUB_REF_NAME
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
        github_api_post() { echo "403"; }
        export -f github_api_post
      }

      It 'fails with error about missing permissions'
        export ACTIONS_TYPE="pr"
        When run validate_permissions
        The status should be failure
        The stdout should include "Validating GitHub Permissions"
        The stderr should include "pull-requests: write permission not granted"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=Missing PR permissions"
      End
    End

    Context 'ACTIONS_TYPE=commit with insufficient permissions'
      BeforeEach 'setup_insufficient_commit_permissions'

      setup_insufficient_commit_permissions() {
        github_api_post() { echo "403"; }
        export -f github_api_post
      }

      It 'fails with error about missing permissions'
        export ACTIONS_TYPE="commit"
        When run validate_permissions
        The status should be failure
        The stdout should include "Validating GitHub Permissions"
        The stderr should include "contents: write permission not granted"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "status=error"
        The contents of file "$GITHUB_OUTPUT_FILE" should include "message=Missing commit permissions"
      End
    End
  End
End
