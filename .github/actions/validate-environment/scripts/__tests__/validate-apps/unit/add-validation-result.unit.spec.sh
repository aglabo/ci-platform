#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/unit/add-validation-result.unit.spec.sh
# @(#) : Unit tests for add_validation_result() in validate-apps.sh

Describe 'add_validation_result()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"

  BeforeEach 'setup_globals'
  AfterEach 'teardown_globals'

  setup_globals() {
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  teardown_globals() {
    unset VALIDATION_RESULTS
    VALIDATION_INDEX=0
  }

  Context 'success entry'
    It 'returns success status'
      When call add_validation_result "git" "Git" "success" "2.52.0" "-"
      The status should be success
    End

    It 'adds entry to VALIDATION_RESULTS array'
      check_count() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${#VALIDATION_RESULTS[@]}"
      }
      When call check_count
      The output should equal "1"
    End

    It 'stored JSON contains correct status field'
      check_json_status() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.status' | tr -d '\r'
      }
      When call check_json_status
      The output should equal "success"
    End

    It 'stored JSON contains correct app field'
      check_json_app() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.app' | tr -d '\r'
      }
      When call check_json_app
      The output should equal "Git"
    End

    It 'stored JSON contains correct cmd field'
      check_json_cmd() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.cmd' | tr -d '\r'
      }
      When call check_json_cmd
      The output should equal "git"
    End

    It 'stored JSON contains correct version field'
      check_json_version() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.version' | tr -d '\r'
      }
      When call check_json_version
      The output should equal "2.52.0"
    End
  End

  Context 'error entry'
    It 'adds error entry to VALIDATION_RESULTS array'
      check_count() {
        add_validation_result "missing" "MissingApp" "error" "" "MissingApp is not installed"
        echo "${#VALIDATION_RESULTS[@]}"
      }
      When call check_count
      The output should equal "1"
    End

    It 'stored JSON contains correct error status'
      check_json_status() {
        add_validation_result "missing" "MissingApp" "error" "" "MissingApp is not installed"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.status' | tr -d '\r'
      }
      When call check_json_status
      The output should equal "error"
    End

    It 'stored JSON contains error message'
      check_json_message() {
        add_validation_result "missing" "MissingApp" "error" "" "MissingApp is not installed"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.message' | tr -d '\r'
      }
      When call check_json_message
      The output should equal "MissingApp is not installed"
    End
  End

  Context 'VALIDATION_INDEX increment'
    It 'VALIDATION_INDEX increments to 1 after one entry'
      check_index() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "$VALIDATION_INDEX"
      }
      When call check_index
      The output should equal "1"
    End

    It 'VALIDATION_INDEX increments to 2 after two entries'
      check_index_two() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        add_validation_result "curl" "curl" "success" "8.5.0" "-"
        echo "$VALIDATION_INDEX"
      }
      When call check_index_two
      The output should equal "2"
    End

    It 'stored JSON contains correct sequential index starting at 0'
      check_json_index() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.index' | tr -d '\r'
      }
      When call check_json_index
      The output should equal "0"
    End
  End

  Context 'abnormal cases - control characters in app_name'
    It 'returns failure when app_name contains newline'
      When call add_validation_result "git" "$(printf 'Git\ninjection')" "success" "2.52.0" "-"
      The status should be failure
      The stderr should include "::error::"
    End

    It 'outputs ::error:: to stderr when app_name has control characters'
      When call add_validation_result "git" "$(printf 'Git\ninjection')" "success" "2.52.0" "-"
      The status should be failure
      The stderr should include "::error::"
    End

    It 'stderr message mentions control characters'
      When call add_validation_result "git" "$(printf 'Git\ninjection')" "success" "2.52.0" "-"
      The status should be failure
      The stderr should include "control characters"
    End
  End

  Context 'edge cases'
    It 'handles empty version string'
      check_empty_version() {
        add_validation_result "curl" "curl" "success" "" "-"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.version' | tr -d '\r'
      }
      When call check_empty_version
      The output should equal ""
    End

    It 'handles empty message string'
      check_empty_message() {
        add_validation_result "git" "Git" "success" "2.52.0" ""
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.message' | tr -d '\r'
      }
      When call check_empty_message
      The output should equal ""
    End

    It 'multiple entries maintain correct order'
      check_order() {
        add_validation_result "git" "Git" "success" "2.52.0" "-"
        add_validation_result "curl" "curl" "error" "" "curl is not installed"
        echo "${VALIDATION_RESULTS[0]}" | jq -r '.cmd' | tr -d '\r'
        echo "${VALIDATION_RESULTS[1]}" | jq -r '.cmd' | tr -d '\r'
      }
      When call check_order
      The line 1 of output should equal "git"
      The line 2 of output should equal "curl"
    End
  End
End
