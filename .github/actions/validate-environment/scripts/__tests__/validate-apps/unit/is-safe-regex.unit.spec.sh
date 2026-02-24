# Copyright (c) 2026 Furukawa Atsushi <atsushifx@gmail.com>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

#!/usr/bin/env bash
# shellcheck shell=sh
# ShellSpec tests for is_safe_regex function

Describe 'is_safe_regex()'
  SCRIPT_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"
  Include "$SCRIPT_PATH"

  Context 'valid regex patterns - returns success'
    It 'accepts alphanumeric pattern'
      When call is_safe_regex "version"
      The status should be success
    End

    It 'accepts version pattern with brackets'
      When call is_safe_regex "[0-9.]+"
      The status should be success
    End

    It 'accepts capture group pattern with space'
      When call is_safe_regex "version ([0-9]+)"
      The status should be success
    End

    It 'accepts pattern with hyphen and brackets'
      When call is_safe_regex "[0-9]+-[a-z]+"
      The status should be success
    End
  End

  Context 'empty pattern - returns exit code 1'
    It 'returns exit code 1 for empty string'
      When call is_safe_regex ""
      The status should equal 1
    End

    It 'returns exit code 1 for whitespace-only string'
      When call is_safe_regex "   "
      The status should equal 1
    End
  End

  Context 'control characters - returns exit code 2'
    It 'rejects tab character'
      When call is_safe_regex $'test\tpattern'
      The status should equal 2
    End

    It 'rejects newline character'
      When call is_safe_regex $'test\npattern'
      The status should equal 2
    End
  End

  Context 'dangerous metacharacters - returns exit code 3'
    It 'rejects semicolon (command separator)'
      When call is_safe_regex "test;cmd"
      The status should equal 3
    End

    It 'rejects pipe character'
      When call is_safe_regex "test|cmd"
      The status should equal 3
    End

    It 'rejects ampersand (background/AND operator)'
      When call is_safe_regex "test&cmd"
      The status should equal 3
    End

    It 'rejects backslash (escape injection)'
      When call is_safe_regex 'test\pattern'
      The status should equal 3
    End

    It 'rejects greater-than sign (redirect)'
      When call is_safe_regex "test>output"
      The status should equal 3
    End

    It 'rejects single quote'
      When call is_safe_regex "test'quoted'"
      The status should equal 3
    End

    It 'rejects double quote'
      When call is_safe_regex 'test"quoted"'
      The status should equal 3
    End

    It 'rejects brace expansion'
      When call is_safe_regex "test{a,b}"
      The status should equal 3
    End

    It 'rejects backslash-n (backslash is dangerous metacharacter)'
      When call is_safe_regex 'test\npattern'
      The status should equal 3
    End

  End

  Context 'shell injection patterns - returns exit code 4'
    It 'rejects dollar sign (variable expansion)'
      When call is_safe_regex 'test$var'
      The status should equal 4
    End

    It 'rejects backtick (command substitution)'
      When call is_safe_regex 'test`cmd`'
      The status should equal 4
    End

    It 'rejects command substitution $(...)'
      When call is_safe_regex 'test$(cmd)'
      The status should equal 4
    End

    It 'rejects hash character (comment)'
      When call is_safe_regex "test#pattern"
      The status should equal 4
    End

    It 'rejects exclamation mark (history expansion)'
      When call is_safe_regex "test!history"
      The status should equal 4
    End

    It 'rejects forward slash (potential path injection)'
      When call is_safe_regex "a/b"
      The status should equal 4
    End
  End
End
