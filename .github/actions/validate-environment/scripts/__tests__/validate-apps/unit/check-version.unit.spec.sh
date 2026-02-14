#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/check-version.spec.sh
# ShellSpec tests for check_version function

Describe 'check_version()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  Context 'version comparison - success cases'
    It 'returns SUCCESS when version meets minimum'
      When call check_version "2.52.0" "2.30"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns SUCCESS when version equals minimum'
      When call check_version "2.30" "2.30"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns SUCCESS for higher major version'
      When call check_version "3.0.0" "2.99.99"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns SUCCESS for higher patch version'
      When call check_version "2.30.1" "2.30.0"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End
  End

  Context 'version comparison - failure cases'
    It 'returns FAILURE when version is below minimum'
      When call check_version "2.20" "2.30"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End

    It 'returns FAILURE for lower major version'
      When call check_version "1.99.99" "2.0.0"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End

    It 'returns FAILURE for lower patch version'
      When call check_version "2.30.0" "2.30.1"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End
  End

  Context 'semver edge cases'
    It 'handles X.Y format'
      When call check_version "2.5" "2.3"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'handles mixed X.Y and X.Y.Z formats'
      When call check_version "2.5" "2.3.0"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End
  End
End
