#!/usr/bin/env bash
# shellcheck shell=sh
# ShellSpec tests for validate_app_special function

Describe 'validate_app_special()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"
  Include "$SCRIPT_PATH"

  Context 'gh authentication - success cases'
    check_gh_authentication() { return 0; }

    It 'returns SUCCESS when gh is authenticated'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking GitHub CLI authentication..."
      The stderr should include "✓ GitHub CLI is authenticated"
    End
  End

  Context 'gh authentication - failure cases'
    check_gh_authentication() { return 1; }

    It 'returns ERROR when gh is not authenticated'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::GitHub CLI is not authenticated"
      The stderr should include "gh auth login"
    End

    It 'includes proper error message format'
      When call validate_app_special "gh" "gh"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should start with "Checking gh authentication"
    End
  End

  Context 'non-special applications'
    It 'returns SUCCESS for git (no special validation)'
      When call validate_app_special "git" "Git"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'returns SUCCESS for curl (no special validation)'
      When call validate_app_special "curl" "curl"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'returns SUCCESS for bash (no special validation)'
      When call validate_app_special "bash" "Bash"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'does not output stderr for non-special apps'
      When call validate_app_special "unknown-app" "Unknown"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should be blank
    End
  End

  Context 'output format validation'
    check_gh_authentication() { return 0; }

    It 'outputs status on line 1, logs on stderr'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The line 2 of output should be undefined
      The stderr should not be blank
    End
  End

  Context 'exit codes'
    It 'returns 0 for successful validation (gh authenticated)'
      check_gh_authentication() { return 0; }
      When call validate_app_special "gh" "gh"
      The status should equal 0
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End

    It 'returns 1 for failed validation (gh not authenticated)'
      check_gh_authentication() { return 1; }
      When call validate_app_special "gh" "gh"
      The status should equal 1
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'returns 0 for non-special apps'
      When call validate_app_special "git" "Git"
      The status should equal 0
      The line 1 of output should start with "SUCCESS:"
      The stderr should be blank
    End
  End

  Context 'empty cmd argument'
    It 'returns SUCCESS for empty cmd (no special validation needed)'
      When call validate_app_special "" "Unknown App"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'outputs nothing to stderr for empty cmd'
      When call validate_app_special "" ""
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should be blank
    End
  End

  Context 'gh authentication failure - error message format'
    check_gh_authentication() { return 1; }

    It 'includes gh auth login instruction in stderr'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "gh auth login"
    End

    It 'includes ::error:: prefix in stderr'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::"
    End

    It 'stderr error message mentions app_name'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "GitHub CLI"
    End
  End

  Context 'gh authentication success - stderr content'
    check_gh_authentication() { return 0; }

    It 'includes checkmark symbol in stderr on success'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "✓ GitHub CLI is authenticated"
    End

    It 'includes authentication checking message in stderr'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "Checking GitHub CLI authentication..."
    End

    It 'outputs SUCCESS on line 1 and nothing on line 2'
      When call validate_app_special "gh" "GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The line 2 of output should be undefined
      The stderr should not be blank
    End
  End
End
