#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for validate_app_format function
# Tests:
#   1. Field count validation (2 or 4 pipe-delimited fields)
#   2. Command name security (relative paths, shell metacharacters)

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

  Context 'security: relative path rejection'
    It 'rejects relative path with ./ prefix'
      When call validate_app_format "./malicious|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "relative path"
      The stderr should include "::error::"
    End

    It 'rejects relative path with ../ prefix'
      When call validate_app_format "../malicious|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "relative path"
      The stderr should include "::error::"
    End

    It 'rejects embedded ./ in path'
      When call validate_app_format "/usr/./bin/malicious|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "relative path"
      The stderr should include "::error::"
    End

    It 'rejects embedded ../ in path'
      When call validate_app_format "/usr/../bin/malicious|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "relative path"
      The stderr should include "::error::"
    End

    It 'allows absolute paths without relative components'
      When call validate_app_format "/usr/bin/git|Git"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End
  End

  Context 'security: shell metacharacter rejection'
    It 'rejects semicolon in command name'
      When call validate_app_format "git;rm -rf|Malicious"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    # Note: Pipe character (|) test is omitted because it's used as field delimiter
    # A pipe in the cmd field would be interpreted as delimiter, causing field count error
    # This is structurally prevented by the pipe-delimited format itself

    It 'rejects ampersand in command name'
      When call validate_app_format "git&|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    It 'rejects dollar sign in command name'
      When call validate_app_format "\$malicious|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    It 'rejects backtick in command name'
      When call validate_app_format "\`malicious\`|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    It 'rejects parentheses in command name'
      When call validate_app_format "git()|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    It 'rejects space in command name'
      When call validate_app_format "git pull|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "metacharacters"
      The stderr should include "::error::"
    End

    It 'rejects tab in command name'
      When call validate_app_format "git	tab|App"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The line 1 of output should include "control characters"
      The stderr should include "::error::"
    End

    It 'allows hyphens in command name'
      When call validate_app_format "node-gyp|Node GYP"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'allows underscores in command name'
      When call validate_app_format "my_command|My Command"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End

    It 'allows forward slashes in absolute paths'
      When call validate_app_format "/usr/local/bin/gh|GitHub CLI"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
    End
  End
End
