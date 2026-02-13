#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for initialize_apps_list function
# Tests integration of defaults + stdin + validation

Describe 'initialize_apps_list()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Reset global APPS array before each test
  BeforeEach 'setup_test'
  setup_test() {
    APPS=()
  }

  Context 'default apps only (no stdin)'
    It 'sets APPS array with default apps when no stdin'
      Data
        # No stdin data
      End
      When call initialize_apps_list "git|Git|regex:version ([0-9.]+)|2.0" "curl|cURL|regex:curl ([0-9.]+)|7.0"
      The status should be success
      The variable APPS[0] should equal "git|Git|regex:version ([0-9.]+)|2.0"
      The variable APPS[1] should equal "curl|cURL|regex:curl ([0-9.]+)|7.0"
    End

    It 'sets empty APPS array when no defaults and no stdin'
      Data
        # No stdin data
      End
      When call initialize_apps_list
      The status should be success
      The value "${#APPS[@]}" should equal 0
    End

    It 'sets APPS array with multiple default apps in order'
      Data
        # No stdin data
      End
      When call initialize_apps_list "app1|App1" "app2|App2" "app3|App3"
      The status should be success
      The variable APPS[0] should equal "app1|App1"
      The variable APPS[1] should equal "app2|App2"
      The variable APPS[2] should equal "app3|App3"
    End
  End

  Context 'stdin apps with defaults'
    It 'sets defaults first, then stdin apps in APPS array'
      Data
        #|node|Node.js|regex:v([0-9.]+)|18.0
        #|docker|Docker|regex:([0-9.]+)|20.0
      End
      When call initialize_apps_list "git|Git" "curl|cURL"
      The status should be success
      The variable APPS[0] should equal "git|Git"
      The variable APPS[1] should equal "curl|cURL"
      The variable APPS[2] should equal "node|Node.js|regex:v([0-9.]+)|18.0"
      The variable APPS[3] should equal "docker|Docker|regex:([0-9.]+)|20.0"
    End

    It 'handles multiple stdin lines'
      Data
        #|python|Python|regex:([0-9.]+)|3.9
        #|ruby|Ruby|regex:([0-9.]+)|3.0
        #|java|Java|regex:([0-9.]+)|11.0
      End
      When call initialize_apps_list
      The status should be success
      The value "${#APPS[@]}" should equal 3
      The variable APPS[0] should equal "python|Python|regex:([0-9.]+)|3.9"
      The variable APPS[1] should equal "ruby|Ruby|regex:([0-9.]+)|3.0"
      The variable APPS[2] should equal "java|Java|regex:([0-9.]+)|11.0"
    End

    It 'combines 2 defaults + 3 stdin apps correctly'
      Data
        #|node|Node.js|regex:v([0-9.]+)|18.0
        #|docker|Docker|regex:([0-9.]+)|20.0
        #|python|Python|regex:([0-9.]+)|3.9
      End
      When call initialize_apps_list "git|Git" "curl|cURL"
      The status should be success
      The value "${#APPS[@]}" should equal 5
      The variable APPS[0] should equal "git|Git"
      The variable APPS[1] should equal "curl|cURL"
      The variable APPS[2] should equal "node|Node.js|regex:v([0-9.]+)|18.0"
      The variable APPS[3] should equal "docker|Docker|regex:([0-9.]+)|20.0"
      The variable APPS[4] should equal "python|Python|regex:([0-9.]+)|3.9"
    End
  End

  Context 'format validation'
    It 'accepts valid stdin apps (2 fields)'
      Data
        #|git|Git
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "git|Git"
    End

    It 'rejects invalid stdin apps (3 fields)'
      Data
        #|node|Node.js|regex:v([0-9.]+)
      End
      When call initialize_apps_list
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "expected 2 or 4 pipe-delimited fields"
      The stderr should include "got 3"
    End

    It 'accepts valid stdin apps (4 fields)'
      Data
        #|docker|Docker|regex:([0-9.]+)|20.0
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "docker|Docker|regex:([0-9.]+)|20.0"
    End

    It 'rejects invalid stdin app (1 field) and exits 1'
      Data
        #|invalid_app_no_pipes
      End
      When call initialize_apps_list
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "expected 2 or 4 pipe-delimited fields"
    End

    It 'rejects invalid stdin app (5 fields) and exits 1'
      Data
        #|git|Git|regex:v([0-9.]+)|2.0|extra_field
      End
      When call initialize_apps_list
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "expected 2 or 4 pipe-delimited fields"
    End

    It 'stops processing on first invalid line (fail-fast)'
      Data
        #|git|Git
        #|invalid_app
        #|node|Node.js
      End
      When call initialize_apps_list
      The status should be failure
      The stderr should include "::error::"
      # Should add git to APPS but stop before node
      The variable APPS[0] should equal "git|Git"
      The value "${#APPS[@]}" should equal 1
    End
  End

  Context 'edge cases'
    It 'filters whitespace-only lines before validation'
      Data
        #|git|Git
        #|
        #|node|Node.js
      End
      When call initialize_apps_list
      The status should be success
      The value "${#APPS[@]}" should equal 2
      The variable APPS[0] should equal "git|Git"
      The variable APPS[1] should equal "node|Node.js"
    End

    It 'filters empty lines before validation'
      Data
        #|git|Git
        #|
        #|node|Node.js
      End
      When call initialize_apps_list
      The status should be success
      The value "${#APPS[@]}" should equal 2
      The variable APPS[0] should equal "git|Git"
      The variable APPS[1] should equal "node|Node.js"
    End

    It 'handles empty stdin (no data within timeout)'
      Data
        # Completely empty
      End
      When call initialize_apps_list "git|Git"
      The status should be success
      The variable APPS[0] should equal "git|Git"
    End

    It 'handles all-whitespace stdin'
      Data
        #|
        #|
        #|
      End
      When call initialize_apps_list "git|Git"
      The status should be success
      The variable APPS[0] should equal "git|Git"
      The value "${#APPS[@]}" should equal 1
    End
  End

  Context 'order preservation'
    It 'maintains order: default1, default2, stdin1, stdin2'
      Data
        #|stdin1|StdIn1
        #|stdin2|StdIn2
      End
      When call initialize_apps_list "default1|Default1" "default2|Default2"
      The status should be success
      The variable APPS[0] should equal "default1|Default1"
      The variable APPS[1] should equal "default2|Default2"
      The variable APPS[2] should equal "stdin1|StdIn1"
      The variable APPS[3] should equal "stdin2|StdIn2"
    End

    It 'preserves stdin order even with many lines'
      Data
        #|app1|App1
        #|app2|App2
        #|app3|App3
        #|app4|App4
        #|app5|App5
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "app1|App1"
      The variable APPS[1] should equal "app2|App2"
      The variable APPS[2] should equal "app3|App3"
      The variable APPS[3] should equal "app4|App4"
      The variable APPS[4] should equal "app5|App5"
    End
  End

  Context 'special characters in app definitions'
    It 'handles regex patterns with special chars'
      Data
        #|node|Node.js|regex:v([0-9.]+)|18.0
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "node|Node.js|regex:v([0-9.]+)|18.0"
    End

    It 'handles spaces in app names'
      Data
        #|code|Visual Studio Code|regex:([0-9.]+)|1.0
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "code|Visual Studio Code|regex:([0-9.]+)|1.0"
    End

    It 'allows empty fields in middle positions'
      Data
        #|docker|Docker||
      End
      When call initialize_apps_list
      The status should be success
      The variable APPS[0] should equal "docker|Docker||"
    End
  End
End
