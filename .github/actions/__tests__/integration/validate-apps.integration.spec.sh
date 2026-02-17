#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps.spec.sh
# ShellSpec tests for validate_apps function

Describe 'validate_apps()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Mock GITHUB_OUTPUT
  export GITHUB_OUTPUT="/dev/null"
  export FAIL_FAST="true"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Reset global arrays before each test
  BeforeEach 'setup_test'
  setup_test() {
    declare -ga VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  # Extract validated apps from VALIDATION_RESULTS
  get_validated_apps() {
    local -a apps=()
    mapfile -d '' -t apps < <(
      printf '%s\n' "${VALIDATION_RESULTS[@]}" \
        | jq -jr 'select(.status == "success") | (.app, "\u0000")' \
        | tr -d '\r'
    )
    printf '%s\n' "${apps[@]}"
  }

  # Extract validated versions from VALIDATION_RESULTS
  get_validated_versions() {
    local -a versions=()
    mapfile -d '' -t versions < <(
      printf '%s\n' "${VALIDATION_RESULTS[@]}" \
        | jq -jr 'select(.status == "success") | (.version, "\u0000")' \
        | tr -d '\r'
    )
    printf '%s\n' "${versions[@]}"
  }

  # Get app at specific index
  get_validated_app_at() {
    local index=$1
    printf '%s\n' "${VALIDATION_RESULTS[@]}" \
      | jq -r "select(.status == \"success\") | select(.index == $index) | .app"
  }

  # Get version at specific index
  get_validated_version_at() {
    local index=$1
    printf '%s\n' "${VALIDATION_RESULTS[@]}" \
      | jq -r "select(.status == \"success\") | select(.index == $index) | .version"
  }

  # Count successful validations
  get_validated_count() {
    printf '%s\n' "${VALIDATION_RESULTS[@]}" \
      | jq -r 'select(.status == "success")' \
      | wc -l
  }

  Context '2-field format (cmd|app_name) - success cases'
    It 'validates single 2-field app successfully'
      When call validate_apps "git|Git"
      The status should be success
      The value "$(get_validated_apps)" should equal "Git"
      The stderr should include "Checking Git..."
    End

    It 'validates multiple 2-field apps successfully'
      When call validate_apps "git|Git" "bash|Bash"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "Git"
      The value "$(get_validated_app_at 1)" should equal "Bash"
    End

    It 'stores app names in VALIDATED_APPS array'
      When call validate_apps "curl|cURL" "git|Git"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "cURL"
      The value "$(get_validated_app_at 1)" should equal "Git"
    End

    It 'skips version check for 2-field apps (shows warning)'
      When call validate_apps "git|Git"
      The status should be success
      The stderr should include "::warning::"
      The stderr should include "version check skipped"
    End
  End

  Context '4-field format (cmd|app_name|version_extractor|min_version) - success cases'
    It 'validates single 4-field app successfully'
      When call validate_apps "git|Git|field:3|2.0"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_apps)" should equal "Git"
    End

    It 'validates multiple 4-field apps successfully'
      When call validate_apps "git|Git|field:3|2.0" "bash|Bash|regex:version ([0-9.]+)|4.0"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "Git"
      The value "$(get_validated_app_at 1)" should equal "Bash"
    End

    It 'performs version check against minimum requirement'
      When call validate_apps "git|Git|field:3|2.0"
      The status should be success
      The stderr should include "✓"
      The stderr should include "git version"
    End
  End

  Context 'mixed formats'
    It 'validates mix of 2-field and 4-field apps'
      When call validate_apps "curl|cURL" "git|Git|field:3|2.0"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "cURL"
      The value "$(get_validated_app_at 1)" should equal "Git"
    End

    It 'handles empty version_extractor (auto semver detection)'
      When call validate_apps "git|Git||2.0"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_apps)" should equal "Git"
    End

    It 'handles empty min_version (skip version check with warning)'
      When call validate_apps "git|Git|field:3|"
      The status should be success
      The value "$(get_validated_apps)" should equal "Git"
      The stderr should include "::warning::"
      The stderr should include "version check skipped"
    End
  End

  Context 'VALIDATED_APPS and VALIDATED_VERSIONS arrays'
    It 'populates VALIDATED_APPS with app names'
      When call validate_apps "git|Git" "bash|Bash"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "Git"
      The value "$(get_validated_app_at 1)" should equal "Bash"
    End

    It 'populates VALIDATED_VERSIONS with version strings'
      When call validate_apps "git|Git"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_version_at 0)" should include "git version"
    End

    It 'arrays have matching indices for multiple apps'
      When call validate_apps "git|Git" "bash|Bash"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "Git"
      The value "$(get_validated_app_at 1)" should equal "Bash"
      The value "$(get_validated_version_at 0)" should include "git"
      The value "$(get_validated_version_at 1)" should include "bash"
    End
  End

  Context 'special validation (gh authentication)'
    # Mock gh authentication check to succeed
    check_gh_authentication() { return 0; }

    It 'performs special validation for gh command'
      When call validate_apps "gh|GitHub CLI|regex:version ([0-9.]+)|2.0"
      The status should be success
      The value "$(get_validated_apps)" should include "GitHub CLI"
      The stderr should include "Checking GitHub CLI authentication"
    End
  End

  Context 'empty input'
    It 'handles empty app list gracefully'
      When call validate_apps
      The status should be success
      The value "$(get_validated_count)" should equal "0"
    End
  End

  Context 'edge cases'
    It 'handles app name with spaces'
      When call validate_apps "git|Git CLI Tool"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_apps)" should equal "Git CLI Tool"
    End

    It 'handles version extractor with regex special chars'
      When call validate_apps "git|Git|regex:version ([0-9.]+)|2.0"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_apps)" should equal "Git"
    End

    It 'handles multiple consecutive validations'
      When call validate_apps "git|Git" "curl|cURL" "bash|Bash"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_app_at 0)" should equal "Git"
      The value "$(get_validated_app_at 1)" should equal "cURL"
      The value "$(get_validated_app_at 2)" should equal "Bash"
    End
  End

  Context 'error cases - invalid format'
    It 'rejects 3-field format (cmd|app_name|extractor)'
      # 3-field format is ambiguous - missing min_version
      When call validate_apps "git|Git|field:3"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "Invalid app definition format"
      The stderr should include "expected 2 or 4"
    End

    It 'rejects 1-field format (cmd only)'
      When call validate_apps "git"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "Invalid app definition format"
    End

    It 'rejects 5-field format (too many fields)'
      When call validate_apps "git|Git|field:3|2.0|extra"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "Invalid app definition format"
    End

    It 'continues to next app after format error (fail-fast disabled)'
      # First app has invalid format, second is valid
      When call validate_apps "git|Git|field:3" "bash|Bash"
      The status should be failure
      The stderr should include "::error::"
      # bash should NOT be validated due to fail-fast
      The value "$(get_validated_count)" should equal "0"
    End
  End

  Context 'error cases - missing command'
    It 'rejects non-existent command'
      When call validate_apps "nonexistent_cmd_12345|Test App"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "is not installed"
    End

    It 'rejects empty command name'
      When call validate_apps "|Empty Command"
      The status should be failure
      The stderr should include "::error::"
    End
  End

  Context 'error cases - version check failures'
    It 'fails when version is below minimum requirement'
      # Git version is 2.53.x, require impossibly high version
      When call validate_apps "git|Git|field:3|999.0"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "version"
    End

    It 'fails with invalid version extractor'
      # Invalid extractor format should cause error
      When call validate_apps "git|Git|invalid_format|2.0"
      The status should be failure
      The stderr should include "::error::"
    End
  End

  Context 'edge cases - special characters'
    It 'handles pipe character in app name (escaped)'
      # This should fail format validation
      When call validate_apps "git|Git | Tool"
      The status should be failure
      The stderr should include "::error::"
    End

    It 'handles empty app name'
      When call validate_apps "git|"
      The status should be success
      The stderr should include "Checking"
      The value "$(get_validated_apps)" should equal ""
    End
  End

  Context 'edge cases - gh authentication failures'
    # Mock gh authentication to fail
    check_gh_authentication() { return 1; }

    It 'fails when gh authentication check fails'
      When call validate_apps "gh|GitHub CLI|regex:version ([0-9.]+)|2.0"
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "authentication"
    End
  End
End
