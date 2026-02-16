#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/unit/validate-app-version.unit.spec.sh
# @(#) : Unit tests for validate_app_version() in validate-apps.sh

Describe 'validate_app_version()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"

  Context 'Guard 1: get_app_version() failure'
    get_app_version() { return 1; }

    It 'returns failure status when get_app_version fails'
      When call validate_app_version "badcmd" "BadApp" "field:3" "2.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'outputs ERROR status line on stdout when get_app_version fails'
      When call validate_app_version "badcmd" "BadApp" "field:3" "2.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'ERROR message mentions app name on stderr'
      When call validate_app_version "badcmd" "BadApp" "field:3" "2.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should include "BadApp"
    End
  End

  Context 'Guard 2: min_ver is empty (skip version check)'
    get_app_version() { echo "testapp 1.2.3"; return 0; }

    It 'returns success when min_ver is empty'
      When call validate_app_version "testcmd" "TestApp" "field:2" ""
      The status should be success
      The line 1 of output should start with "WARNING:"
      The stderr should not be blank
    End

    It 'outputs WARNING status line when min_ver is empty'
      When call validate_app_version "testcmd" "TestApp" "field:2" ""
      The status should be success
      The line 1 of output should start with "WARNING:"
      The stderr should not be blank
    End

    It 'WARNING message indicates version check was skipped'
      When call validate_app_version "testcmd" "TestApp" "" ""
      The status should be success
      The line 1 of output should include "skipped"
      The stderr should not be blank
    End
  End

  Context 'Guard 3: extract_version_number() failure'
    get_app_version() { echo "testapp unknownformat"; return 0; }

    It 'returns failure when version extraction fails with unknown extractor'
      When call validate_app_version "testcmd" "TestApp" "field:99" "2.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'outputs ERROR status line when regex pattern does not match'
      When call validate_app_version "testcmd" "TestApp" "regex:v([0-9.]+)" "2.0"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'ERROR message indicates Version extraction failed'
      When call validate_app_version "testcmd" "TestApp" "regex:v([0-9.]+)" "2.0"
      The status should be failure
      The line 1 of output should include "Version extraction failed"
      The stderr should not be blank
    End
  End

  Context 'Guard 4: version below minimum'
    get_app_version() { echo "git version 2.20.0"; return 0; }

    It 'returns failure when version is below minimum (field:3 extractor)'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'outputs ERROR status line when version is below minimum'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be failure
      The line 1 of output should start with "ERROR:"
      The stderr should not be blank
    End

    It 'ERROR message mentions below minimum'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be failure
      The line 1 of output should include "below minimum"
      The stderr should not be blank
    End
  End

  Context 'success cases - field:N extractor'
    get_app_version() { echo "git version 2.52.0"; return 0; }

    It 'returns success when version meets minimum (field:3)'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End

    It 'outputs SUCCESS status line (field:3 extractor)'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End

    It 'SUCCESS message includes extracted version'
      When call validate_app_version "git" "Git" "field:3" "2.30"
      The status should be success
      The line 1 of output should include "2.52.0"
      The stderr should not be blank
    End
  End

  Context 'success cases - regex extractor'
    get_app_version() { echo "gh version 2.61.0 (2026-01-27)"; return 0; }

    It 'returns success when version meets minimum (regex extractor)'
      When call validate_app_version "gh" "GitHub CLI" "regex:version ([0-9.]+)" "2.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End

    It 'outputs SUCCESS status line (regex extractor)'
      When call validate_app_version "gh" "GitHub CLI" "regex:version ([0-9.]+)" "2.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End
  End

  Context 'success cases - auto extractor'
    get_app_version() { echo "curl 8.5.0 (x86_64-pc-linux-gnu)"; return 0; }

    It 'returns success when version meets minimum (auto/empty extractor)'
      When call validate_app_version "curl" "curl" "" "7.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End

    It 'outputs SUCCESS status line (auto extractor)'
      When call validate_app_version "curl" "curl" "" "7.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End
  End

  Context 'edge case - version exactly equals minimum'
    get_app_version() { echo "git version 2.30.0"; return 0; }

    It 'returns success when version exactly equals minimum'
      When call validate_app_version "git" "Git" "field:3" "2.30.0"
      The status should be success
      The line 1 of output should start with "SUCCESS:"
      The stderr should not be blank
    End
  End
End
