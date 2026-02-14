#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-app-exists.spec.sh
# ShellSpec tests for validate_app_exists function

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
    End
  End

  Context 'security validation - shell metacharacters'
    It 'returns ERROR for command with semicolon'
      When call validate_app_exists "git;ls" "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
      The stderr should include "::error::"
    End

    It 'returns ERROR for command with pipe'
      When call validate_app_exists "git|ls" "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'returns ERROR for command with ampersand'
      When call validate_app_exists "git&ls" "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'returns ERROR for command with dollar sign'
      When call validate_app_exists 'git$(ls)' "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'returns ERROR for command with backtick'
      When call validate_app_exists 'git`ls`' "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'returns ERROR for command with parentheses'
      When call validate_app_exists 'git(ls)' "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'returns ERROR for command with space'
      When call validate_app_exists "git ls" "Evil"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End
  End

  Context 'missing commands'
    It 'returns ERROR for non-existent command'
      When call validate_app_exists "nonexistentcmd12345" "NonExistent"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "is not installed"
      The stderr should include "::error::"
    End
  End

  Context 'edge cases - paths and special formats'
    It 'handles absolute path to command'
      When call validate_app_exists "/usr/bin/env" "env (absolute)"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'rejects relative path (security)'
      When call validate_app_exists "./bin/myapp" "RelativeApp"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'rejects parent directory traversal'
      When call validate_app_exists "../bin/app" "TraversalApp"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "shell metacharacters"
    End

    It 'handles commands with hyphens in name'
      # Most systems have these commands with hyphens
      When call validate_app_exists "bash" "bash-with-test"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'handles commands with underscores in name'
      # Testing that underscores are allowed (common in command names)
      When call validate_app_exists "bash" "test_command"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'rejects forward slash in middle of command (path separator)'
      When call validate_app_exists "usr/bin/git" "PathSeparator"
      The status should be failure
      The line 1 of output should start with "ERROR:"
    End

    It 'rejects backslash (Windows path style)'
      When call validate_app_exists 'git\test' "WindowsPath"
      The status should be failure
      The line 1 of output should start with "ERROR:"
    End
  End
End
