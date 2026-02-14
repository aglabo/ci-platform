#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-app-version.spec.sh
# ShellSpec tests for validate_app_version function

Describe 'validate_app_version()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  Context 'success cases'
    It 'returns SUCCESS for valid version (git)'
      When call validate_app_version "git" "Git" "field:3" "2.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should include "✓"
    End

    It 'returns SUCCESS when version meets minimum'
      When call validate_app_version "bash" "Bash" "regex:version ([0-9.]+)" "4.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'returns WARNING when no minimum version specified'
      When call validate_app_version "git" "Git" "" ""
      The status should be success
      The line 1 of output should start with "WARNING:"
      The line 1 of output should include "version check skipped"
      The stderr should include "::warning::"
    End
  End

  Context 'version too low'
    It 'returns ERROR when version is below minimum'
      When call validate_app_version "git" "Git" "field:3" "999.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "below minimum required"
      The stderr should include "::error::"
    End

    It 'returns ERROR with version details'
      When call validate_app_version "bash" "Bash" "regex:version ([0-9.]+)" "999.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "999.0"
    End
  End

  Context 'extraction errors'
    It 'returns ERROR when extractor is invalid'
      When call validate_app_version "git" "Git" "field:abc" "2.30"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::"
      The stderr should include "Invalid field number"
    End

    It 'returns ERROR when regex pattern does not match'
      When call validate_app_version "git" "Git" "regex:notfound ([0-9.]+)" "2.30"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::"
      The stderr should include "Pattern did not match"
    End
  End
End
