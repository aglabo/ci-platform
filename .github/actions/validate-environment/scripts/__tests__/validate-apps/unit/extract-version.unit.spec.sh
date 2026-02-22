#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/extract-version.spec.sh
# ShellSpec tests for extract_version_number function

Describe 'extract_version_number()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  Context 'field extractor - success cases'
    It 'extracts version using field:3'
      When call extract_version_number "git version 2.52.0" "field:3"
      The output should equal "2.52.0"
      The status should be success
    End

    It 'extracts version from different field positions'
      When call extract_version_number "node v18.20.0" "field:2"
      The output should equal "v18.20.0"
      The status should be success
    End
  End

  Context 'field extractor - error cases'
    It 'returns ERROR and error message for invalid field number (non-numeric)'
      When call extract_version_number "git version 2.52.0" "field:abc"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "Invalid field number"
    End

    It 'returns ERROR and error message for empty field number'
      When call extract_version_number "git version 2.52.0" "field:"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
    End
  End

  Context 'regex extractor - success cases'
    It 'extracts version using regex'
      When call extract_version_number "gh version 2.61.0 (2026-01-27)" "regex:version ([0-9.]+)"
      The output should equal "2.61.0"
      The status should be success
    End

    It 'handles parentheses in input with regex'
      When call extract_version_number "gh (Github CLI) version 2.61.0" "regex:version ([0-9.]+)"
      The output should equal "2.61.0"
      The status should be success
    End

    It 'extracts from complex patterns'
      When call extract_version_number "node v18.20.0" "regex:v([0-9.]+)"
      The output should equal "18.20.0"
      The status should be success
    End
  End

  Context 'regex extractor - error cases'
    It 'returns exit code 2 and error message for empty regex pattern'
      When call extract_version_number "test 1.0" "regex:"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "Empty regex pattern"
    End

    It 'returns exit code 1 and error message when pattern does not match'
      When call extract_version_number "test 1.0" "regex:version ([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "Pattern did not match"
    End
  End

  Context 'auto semver extraction - success cases'
    It 'auto-extracts X.Y.Z format'
      When call extract_version_number "curl 8.17.0" ""
      The output should equal "8.17.0"
      The status should be success
    End

    It 'auto-extracts X.Y format'
      When call extract_version_number "python 3.12" ""
      The output should equal "3.12"
      The status should be success
    End

    It 'extracts first semver when multiple exist'
      When call extract_version_number "tool 1.2.3 compatible with 4.5.6" ""
      The output should equal "1.2.3"
      The status should be success
    End
  End

  Context 'auto semver extraction - error cases'
    It 'returns exit code 1 and error message when no semver pattern found'
      When call extract_version_number "unknown version string" ""
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "No semver pattern found"
    End

    It 'returns exit code 1 and error message for version with parentheses but no semver'
      When call extract_version_number "app (special edition)" ""
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "No semver pattern found"
    End
  End

  Context 'security validation - unsupported characters'
    It 'returns exit code 1 and error message for regex with # character'
      When call extract_version_number "test 1.0" "regex:test#([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "unsupported characters"
    End
  End

  Context 'security validation - shell metacharacters'
    It 'returns exit code 2 and error message for regex with semicolon'
      When call extract_version_number "test 1.0" "regex:test;([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "dangerous shell metacharacters"
    End

    It 'returns exit code 2 and error message for regex with pipe'
      When call extract_version_number "test 1.0" "regex:test|([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "dangerous shell metacharacters"
    End

    It 'returns exit code 2 for regex with ampersand'
      When call extract_version_number "test 1.0" "regex:test&([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
    End

    It 'returns exit code 2 for regex with dollar sign'
      When call extract_version_number "test 1.0" "regex:test\$([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
    End

    It 'returns exit code 2 for regex with backtick'
      When call extract_version_number "test 1.0" "regex:test\`([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
    End

    It 'returns exit code 2 for regex with backslash'
      When call extract_version_number "test 1.0" "regex:test\\([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
    End

    It 'returns exit code 1 and error message for regex with control character (tab)'
      When call extract_version_number "test 1.0" "regex:test$(printf '\t')([0-9.]+)"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "control characters"
    End

    It 'returns exit code 1 and error message when regex matches but has no capture group'
      When call extract_version_number "test 1.0" "regex:[0-9.]+"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "no capture group"
    End
  End


  Context 'unknown extraction method'
    It 'returns exit code 2 and error message for unknown method'
      When call extract_version_number "test 1.0" "unknown:pattern"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "Unknown extraction method"
    End

    It 'returns exit code 2 and error message for invalid method format'
      When call extract_version_number "test 1.0" "invalid"
      The status should equal 1
      The line 1 of output should equal "ERROR"
      The line 2 of output should start with "::error::"
      The line 2 of output should include "Unknown extraction method"
    End
  End
End
