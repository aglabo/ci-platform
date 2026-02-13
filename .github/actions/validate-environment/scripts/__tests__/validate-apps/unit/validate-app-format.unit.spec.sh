#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for validate_app_format function
# Tests field count validation (2 or 4 pipe-delimited fields only)

Describe 'validate_app_format()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  Context 'valid formats'
    It 'accepts 2-field format (cmd|app_name)'
      When call validate_app_format "git|Git"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The lines of output should equal 1
    End

    It 'accepts 4-field format (cmd|app_name|version_extractor|min_version)'
      When call validate_app_format "docker|Docker|regex:([0-9.]+)|20.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The lines of output should equal 1
    End

    It 'allows empty field at end (4 fields: cmd|app|extractor|)'
      When call validate_app_format "docker|Docker|regex:([0-9.]+)|"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The lines of output should equal 1
    End

    It 'allows empty fields in 4-field format (cmd|app||min)'
      When call validate_app_format "curl|cURL||7.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The lines of output should equal 1
    End
  End

  Context 'invalid formats'
    It 'rejects 1-field format (no pipes)'
      When call validate_app_format "git"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "expected 2 or 4 fields"
      The line 1 of output should include "got 1"
      The stderr should include "::error::"
    End

    It 'rejects 3-field format (cmd|app_name|version_extractor)'
      When call validate_app_format "node|Node.js|regex:v([0-9.]+)"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "expected 2 or 4 fields"
      The line 1 of output should include "got 3"
      The stderr should include "::error::"
    End

    It 'rejects 3-field format (cmd|app|extractor)'
      When call validate_app_format "curl|cURL|regex:([0-9.]+)"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "expected 2 or 4 fields"
      The line 1 of output should include "got 3"
      The stderr should include "::error::"
    End

    It 'rejects 5-field format (too many pipes)'
      When call validate_app_format "git|Git|regex:v([0-9.]+)|2.0|extra"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "expected 2 or 4 fields"
      The line 1 of output should include "got 5"
      The stderr should include "::error::"
    End

    It 'rejects 6-field format'
      When call validate_app_format "a|b|c|d|e|f"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "expected 2 or 4 fields"
      The line 1 of output should include "got 6"
      The stderr should include "::error::"
    End

    It 'rejects 0-field format (empty string is considered 1 field)'
      When call validate_app_format ""
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::"
    End
  End

  Context 'error messages'
    It 'outputs ERROR status with message'
      When call validate_app_format "invalid"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "::error::"
    End

    It 'includes the invalid line in stderr'
      When call validate_app_format "invalid_line"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "invalid_line"
    End

    It 'shows actual field count in message'
      When call validate_app_format "one|two|three|four|five|six"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "got 6"
    End
  End
End
