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

  Context 'single component versions'
    It 'returns SUCCESS for single component version meeting minimum'
      When call check_version "3" "2"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns FAILURE for single component version below minimum'
      When call check_version "1" "2"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End

    It 'returns SUCCESS when single component versions are equal'
      When call check_version "5" "5"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns SUCCESS comparing X.Y.Z version with single component min_ver'
      When call check_version "2.30.0" "2"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End
  End

  Context 'four component versions'
    It 'returns SUCCESS for four component version meeting minimum'
      When call check_version "2.30.1.5" "2.30.1.4"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns FAILURE for four component version below minimum'
      When call check_version "2.30.1.3" "2.30.1.4"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End

    It 'returns SUCCESS when four component versions are equal'
      When call check_version "2.30.1.4" "2.30.1.4"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End
  End

  Context 'zero version boundaries'
    It 'returns SUCCESS for 0.0.1 meeting minimum 0.0.0'
      When call check_version "0.0.1" "0.0.0"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns SUCCESS when both versions are 0.0.0'
      When call check_version "0.0.0" "0.0.0"
      The status should be success
      The line 1 of output should equal "SUCCESS"
    End

    It 'returns FAILURE for 0.0.0 below minimum 0.0.1'
      When call check_version "0.0.0" "0.0.1"
      The status should be failure
      The line 1 of output should equal "FAILURE"
    End
  End
End
