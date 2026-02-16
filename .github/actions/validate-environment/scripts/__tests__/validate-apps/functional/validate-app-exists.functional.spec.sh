#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-app-exists.spec.sh
# ShellSpec tests for validate_app_exists function
# Tests command existence checking only
# Note: Security validation (metacharacters, relative paths) is tested in validate-app-format.unit.spec.sh

Describe 'validate_app_exists()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  Context 'valid commands'
    It 'returns SUCCESS for existing command (git)'
      When call validate_app_exists "git" "Git"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking Git..."
    End

    It 'returns SUCCESS for existing command (bash)'
      When call validate_app_exists "bash" "Bash"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking Bash..."
    End

    It 'returns SUCCESS for existing command (curl)'
      When call validate_app_exists "curl" "curl"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking curl..."
    End
  End

  Context 'missing commands'
    It 'returns ERROR for non-existent command'
      When call validate_app_exists "nonExistentCmd12345" "NonExistent"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "is not installed"
      The stderr should include "::error::"
    End
  End

  Context 'missing commands - error message content'
    It 'ERROR output includes app name'
      When call validate_app_exists "nonExistentCmd12345" "NonExistentApp"
      The status should be failure
      The line 1 of output should include "NonExistentApp"
      The stderr should include "Checking NonExistentApp..."
    End

    It 'stderr includes app name with ::error:: prefix'
      When call validate_app_exists "nonExistentCmd12345" "NonExistentApp"
      The status should be failure
      The line 1 of output should include "NonExistentApp"
      The stderr should include "::error::NonExistentApp"
    End

    It 'stderr includes is not installed message'
      When call validate_app_exists "nonExistentCmd12345" "NonExistentApp"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "is not installed"
    End
  End

  Context 'missing commands - another command'
    It 'returns ERROR for another non-existent command'
      When call validate_app_exists "anotherMissingCmd99999" "AnotherMissingApp"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "Checking AnotherMissingApp..."
    End

    It 'second missing command ERROR output includes its app name'
      When call validate_app_exists "anotherMissingCmd99999" "AnotherMissingApp"
      The status should be failure
      The line 1 of output should include "AnotherMissingApp"
      The stderr should include "Checking AnotherMissingApp..."
    End
  End

  Context 'edge cases - paths and special formats'
    It 'handles absolute path to command'
      When call validate_app_exists "/usr/bin/env" "env (absolute)"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking env (absolute)..."
    End

    It 'handles commands with hyphens in name'
      # Most systems have these commands with hyphens
      When call validate_app_exists "bash" "bash-with-test"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking bash-with-test..."
    End

    It 'handles commands with underscores in name'
      # Testing that underscores are allowed (common in command names)
      When call validate_app_exists "bash" "test_command"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking test_command..."
    End
  End
End
