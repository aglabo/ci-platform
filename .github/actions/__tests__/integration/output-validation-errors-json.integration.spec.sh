#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/output-validation-errors-json.spec.sh
# ShellSpec tests for output_validation_errors_json function
# JSON-based version of output-validation-errors.spec.sh
# Tests JSON data structures from add_validation_result

Describe 'output_validation_errors_json()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Setup and teardown for each test
  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT=$(mktemp)
    # Direct assignment to clear global array (don't use unset or declare)
    VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT"
  }

  # ========================================
  # Normal Cases: Single Error
  # ========================================
  Context 'normal case: single error'
    It 'outputs complete error information to stderr and GITHUB_OUTPUT'
      add_validation_result "git" "Git" "error" "" "Git is not installed"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="
      The stderr should include "::error::Application validation failed with 1 error(s):"

      # stderr: Error message with prefix
      The stderr should include "::error::  - Git is not installed"

      # GITHUB_OUTPUT: status field
      The contents of file "$GITHUB_OUTPUT" should include "status=error"

      # GITHUB_OUTPUT: message field with multiline EOF
      The contents of file "$GITHUB_OUTPUT" should include "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT" should include "Application validation failed:"
      The contents of file "$GITHUB_OUTPUT" should include "  Git is not installed"
      The contents of file "$GITHUB_OUTPUT" should include "MULTILINE_EOF"

      # GITHUB_OUTPUT: failed_apps field
      The contents of file "$GITHUB_OUTPUT" should include "failed_apps=Git"

      # GITHUB_OUTPUT: count fields
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=1"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=0"
    End
  End

  # ========================================
  # Normal Cases: Multiple Errors
  # ========================================
  Context 'normal case: multiple errors'
    It 'outputs all errors to stderr with correct formatting'
      add_validation_result "git" "Git" "success" "git version 2.53.0" "-"
      add_validation_result "curl" "curl" "error" "" "curl is not installed"
      add_validation_result "gh" "gh" "error" "" "gh version 1.5 is below minimum required 2.0"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header with correct error count
      The stderr should include "::error::Application validation failed with 2 error(s):"

      # stderr: Both error messages present (order may vary)
      The stderr should include "::error::  - curl is not installed"
      The stderr should include "::error::  - gh version 1.5 is below minimum required 2.0"

      # GITHUB_OUTPUT: Both errors in message field with indentation
      The contents of file "$GITHUB_OUTPUT" should include "  curl is not installed"
      The contents of file "$GITHUB_OUTPUT" should include "  gh version 1.5 is below minimum required 2.0"

      # GITHUB_OUTPUT: Count fields
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=1"
    End

    It 'includes both app names in failed_apps (comma-separated)'
      add_validation_result "curl" "curl" "error" "" "curl is not installed"
      add_validation_result "gh" "gh" "error" "" "gh is not authenticated"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"

      # GITHUB_OUTPUT: failed_apps contains both (order may vary)
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*curl*"
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*gh*"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
    End
  End

  # ========================================
  # Normal Cases: Message Formatting
  # ========================================
  Context 'normal case: message formatting'
    It 'indents error messages with exactly 2 spaces in GITHUB_OUTPUT'
      add_validation_result "app1" "App1" "error" "" "Error message 1"
      add_validation_result "app2" "App2" "error" "" "Error message 2"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"

      # GITHUB_OUTPUT: Messages indented with exactly 2 spaces (not 3+)
      The contents of file "$GITHUB_OUTPUT" should include "  Error message 1"
      The contents of file "$GITHUB_OUTPUT" should include "  Error message 2"
      The contents of file "$GITHUB_OUTPUT" should not include "   Error message"
    End

    It 'prefixes stderr messages with "::error::  - "'
      add_validation_result "testapp" "TestApp" "error" "" "Test error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Exact prefix format
      The stderr should include "::error::  - Test error message"
    End
  End

  # ========================================
  # Normal Cases: Complex Error Messages
  # ========================================
  Context 'normal case: complex error messages'
    It 'handles version comparison error messages'
      add_validation_result "curl" "curl" "success" "curl 8.0.0" "-"
      add_validation_result "gh" "gh" "success" "gh version 2.30.0" "-"
      add_validation_result "git" "Git" "error" "" "Git version 2.25 is below minimum required 2.30"
      add_validation_result "node" "Node.js" "error" "" "Node.js version 16.0 is below minimum required 18.0"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Full error messages
      The stderr should include "Git version 2.25 is below minimum required 2.30"
      The stderr should include "Node.js version 16.0 is below minimum required 18.0"

      # GITHUB_OUTPUT: Counts
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=2"
    End

    It 'handles authentication error messages'
      add_validation_result "git" "Git" "success" "git version 2.53.0" "-"
      add_validation_result "curl" "curl" "success" "curl 8.0.0" "-"
      add_validation_result "gh" "gh" "error" "" "gh is not authenticated. Run 'gh auth login' to authenticate."

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Full authentication error with command suggestion
      The stderr should include "gh is not authenticated. Run 'gh auth login' to authenticate."

      # GITHUB_OUTPUT: Full message preserved
      The contents of file "$GITHUB_OUTPUT" should include "  gh is not authenticated. Run 'gh auth login' to authenticate."

      # GITHUB_OUTPUT: Counts
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=1"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=2"
    End

    It 'handles error messages with special characters'
      add_validation_result "test" "Test" "error" "" "Error: Command failed with exit code (127) - not found"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Special characters preserved
      The stderr should include "Error: Command failed with exit code (127) - not found"

      # GITHUB_OUTPUT: Special characters preserved
      The contents of file "$GITHUB_OUTPUT" should include "  Error: Command failed with exit code (127) - not found"
    End
  End

  # ========================================
  # Edge Cases: Empty Arrays
  # ========================================
  Context 'edge case: empty validated_apps'
    It 'outputs validated_count=0 when no apps validated'
      add_validation_result "failedapp" "FailedApp" "error" "" "Some error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"
      The stderr should include "Some error"

      # GITHUB_OUTPUT: Zero validated
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=0"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=1"
    End
  End

  # ========================================
  # Edge Cases: Large Number of Errors
  # ========================================
  Context 'edge case: many errors'
    It 'handles 10+ errors correctly'
      # Create 2 successes and 15 errors
      add_validation_result "validapp1" "ValidApp1" "success" "1.0.0" "-"
      add_validation_result "validapp2" "ValidApp2" "success" "2.0.0" "-"
      for i in $(seq 1 15); do
        add_validation_result "app${i}" "App${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Correct error count
      The stderr should include "::error::Application validation failed with 15 error(s):"

      # GITHUB_OUTPUT: Counts
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=15"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=2"

      # Verify all errors are present in output (sample check)
      The contents of file "$GITHUB_OUTPUT" should include "  Error message 1"
      The contents of file "$GITHUB_OUTPUT" should include "  Error message 15"
    End
  End

  # ========================================
  # Edge Cases: Long Error Messages
  # ========================================
  Context 'edge case: long error messages'
    It 'handles multi-line-like long messages'
      local long_msg="This is a very long error message that contains a lot of detail about what went wrong during validation including version numbers, paths, and troubleshooting suggestions"
      add_validation_result "longapp" "LongApp" "error" "" "$long_msg"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Full message
      The stderr should include "$long_msg"

      # GITHUB_OUTPUT: Full message with indentation
      The contents of file "$GITHUB_OUTPUT" should include "  $long_msg"
    End
  End

  # ========================================
  # Edge Cases: App Names with Special Characters
  # ========================================
  Context 'edge case: app names with special characters'
    It 'handles app names with dots and hyphens'
      add_validation_result "my-app.v2" "my-app.v2" "error" "" "my-app.v2 is not installed"
      add_validation_result "node" "Node.js" "error" "" "Node.js version error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"

      # GITHUB_OUTPUT: failed_apps contains both app names (order may vary)
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*my-app.v2*"
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*Node.js*"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
    End
  End

  # ========================================
  # Edge Cases: Multiline EOF Delimiter
  # ========================================
  Context 'edge case: MULTILINE_EOF delimiter'
    It 'uses correct EOF delimiter format in GITHUB_OUTPUT'
      add_validation_result "testapp" "TestApp" "error" "" "Test error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"

      # GITHUB_OUTPUT: Verify EOF delimiter structure
      The line 2 of contents of file "$GITHUB_OUTPUT" should equal "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT" should include "Application validation failed:"
      # Verify closing delimiter exists
      The contents of file "$GITHUB_OUTPUT" should include "MULTILINE_EOF"
    End
  End

  # ========================================
  # Invariants: Always Returns Failure
  # ========================================
  Context 'invariant: exit status'
    It 'always returns exit status 1 (failure)'
      add_validation_result "anyapp" "AnyApp" "error" "" "Any error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should equal 1
      The stderr should include "::error::"
      The stderr should include "Any error"
    End

    It 'returns failure even with validated apps present'
      add_validation_result "app1" "App1" "success" "1.0" "-"
      add_validation_result "app2" "App2" "success" "2.0" "-"
      add_validation_result "app3" "App3" "success" "3.0" "-"
      add_validation_result "failapp" "FailApp" "error" "" "Error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should equal 1
      The stderr should include "::error::"
      The stderr should include "Error"
    End
  End

  # ========================================
  # Invariants: Required Output Fields
  # ========================================
  Context 'invariant: required GITHUB_OUTPUT fields'
    It 'always includes all required fields'
      add_validation_result "validapp" "ValidApp" "success" "1.0" "-"
      add_validation_result "testapp" "TestApp" "error" "" "Test error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The stderr should include "::error::"

      # All 5 required fields must be present
      The contents of file "$GITHUB_OUTPUT" should include "status=error"
      The contents of file "$GITHUB_OUTPUT" should include "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT" should include "failed_apps="
      The contents of file "$GITHUB_OUTPUT" should include "failed_count="
      The contents of file "$GITHUB_OUTPUT" should include "validated_count="
    End
  End

  # ========================================
  # JSON-Specific: Mixed Success/Error Entries
  # ========================================
  Context 'JSON-specific: mixed success and error entries'
    It 'filters only error entries from mixed results'
      # Add multiple success entries
      for i in $(seq 1 12); do
        add_validation_result "app${i}" "App${i}" "success" "1.0.${i}" "-"
      done

      # Add success entries (should be counted)
      add_validation_result "git" "Git" "success" "git version 2.52.0" "-"
      add_validation_result "curl" "curl" "success" "curl 8.0.1" "-"

      # Add error entries (should be processed)
      add_validation_result "gh" "gh" "error" "" "gh is not installed"
      add_validation_result "node" "Node.js" "error" "" "Node.js version too old"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Only errors present
      The stderr should include "::error::Application validation failed with 2 error(s):"
      The stderr should include "::error::  - gh is not installed"
      The stderr should include "::error::  - Node.js version too old"
      The stderr should not include "git version 2.52.0"
      The stderr should not include "curl 8.0.1"

      # GITHUB_OUTPUT: Only error count
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=14"

      # GITHUB_OUTPUT: failed_apps contains only errors
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*gh*"
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*Node.js*"
    End
  End

  # ========================================
  # JSON-Specific: Order Preservation
  # ========================================
  Context 'JSON-specific: order preservation'
    It 'processes errors in array order (sequential index)'
      # Add errors in specific order
      add_validation_result "app1" "App1" "error" "" "First error"
      add_validation_result "app2" "App2" "error" "" "Second error"
      add_validation_result "app3" "App3" "error" "" "Third error"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # All errors present in output
      The stderr should include "First error"
      The stderr should include "Second error"
      The stderr should include "Third error"

      # GITHUB_OUTPUT: All errors present
      The contents of file "$GITHUB_OUTPUT" should include "  First error"
      The contents of file "$GITHUB_OUTPUT" should include "  Second error"
      The contents of file "$GITHUB_OUTPUT" should include "  Third error"
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=3"
    End
  End

  # ========================================
  # Regression: Comma Separation
  # ========================================
  Context 'regression: comma separation in failed_apps'
    It 'uses commas without spaces to separate app names'
      add_validation_result "app1" "App1" "error" "" "Error 1"
      add_validation_result "app2" "App2" "error" "" "Error 2"
      add_validation_result "app3" "App3" "error" "" "Error 3"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Comma separation without spaces
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*App1*App2*App3*"
      The contents of file "$GITHUB_OUTPUT" should not include "failed_apps=App1, App2"
    End
  End

  # ========================================
  # Boundary: Single Character Values
  # ========================================
  Context 'boundary: single character values'
    It 'handles single-character app names'
      add_validation_result "a" "a" "error" "" "Error a"
      add_validation_result "b" "b" "error" "" "Error b"
      add_validation_result "c" "c" "error" "" "Error c"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Single chars preserved
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*a*"
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*b*"
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*c*"
    End

    It 'handles single-character error messages'
      add_validation_result "app1" "App1" "error" "" "1"
      add_validation_result "app2" "App2" "error" "" "2"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Single char messages preserved
      The contents of file "$GITHUB_OUTPUT" should include "  1"
      The contents of file "$GITHUB_OUTPUT" should include "  2"
    End
  End

  # ========================================
  # Boundary: Maximum Values
  # ========================================
  Context 'boundary: maximum values'
    It 'handles 100+ errors'
      # Create 150 errors
      for i in $(seq 1 150); do
        add_validation_result "app${i}" "App${i}" "error" "" "Error ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Verify count
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=150"
      The contents of file "$GITHUB_OUTPUT" should include "validated_count=0"

      # Spot check first and last
      The contents of file "$GITHUB_OUTPUT" should include "  Error 1"
      The contents of file "$GITHUB_OUTPUT" should include "  Error 150"
    End

    It 'handles very long app name (200 characters)'
      local long_name="$(printf 'A%.0s' {1..200})"
      add_validation_result "longapp" "$long_name" "error" "" "Error for long app"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Long name preserved
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*${long_name}*"
    End
  End

  # ========================================
  # Security: Special Characters
  # ========================================
  Context 'security: special characters in values'
    It 'rejects newlines in app name (security: prevent log injection)'
      # Security: app_name with control characters should be rejected
      When call add_validation_result "app-newline" "App"$'\n'"Name" "error" "" "Some error"
      The status should be failure
      The stderr should include "::error::Invalid app_name"
      The stderr should include "contains control characters"
    End

    It 'handles quotes in error message'
      add_validation_result "app1" "App1" "error" "" "Error \"with\" quotes"
      add_validation_result "app2" "App2" "error" "" "Error 'with' quotes"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Quotes should be preserved
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=2"
    End

    It 'handles dollar signs in error message'
      add_validation_result "app" "App" "error" "" 'Error $1.0 (build $100)'

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Dollar signs should not be expanded
      The contents of file "$GITHUB_OUTPUT" should include '$1.0'
      The contents of file "$GITHUB_OUTPUT" should include '$100'
    End

    It 'handles backticks in error message'
      add_validation_result "app" "App" "error" "" 'Error: `command` failed'

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Backticks should not be executed
      The contents of file "$GITHUB_OUTPUT" should include '`command`'
    End

    It 'handles semicolons and pipes in error message'
      add_validation_result "app" "App" "error" "" 'Error; echo "injection" | cat'

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Shell metacharacters should not be executed
      The contents of file "$GITHUB_OUTPUT" should include 'Error; echo'
    End
  End

  # ========================================
  # Format: Whitespace Handling
  # ========================================
  Context 'format: whitespace handling'
    It 'handles leading whitespace in app name'
      add_validation_result "leading" "  LeadingSpace" "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Leading space preserved
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*  LeadingSpace*"
    End

    It 'handles trailing whitespace in app name'
      add_validation_result "trailing" "TrailingSpace  " "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Trailing space preserved
      The contents of file "$GITHUB_OUTPUT" should match pattern "*failed_apps=*TrailingSpace  *"
    End

    It 'handles multiple consecutive spaces in app name'
      add_validation_result "spaces" "App    With    Spaces" "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Multiple spaces preserved
      The contents of file "$GITHUB_OUTPUT" should include "App    With    Spaces"
    End

    It 'rejects tab characters in app name (security: prevent log injection)'
      # Security: app_name with control characters should be rejected
      When call add_validation_result "tab" "App"$'\t'"WithTab" "error" "" "Some error"
      The status should be failure
      The stderr should include "::error::Invalid app_name"
      The stderr should include "contains control characters"
    End
  End

  # ========================================
  # Format: Empty Values
  # ========================================
  Context 'format: empty values'
    It 'handles empty string in app name'
      add_validation_result "empty" "" "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Empty app name case
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=1"
    End

    It 'handles empty string in error message'
      add_validation_result "app" "App" "error" "" ""

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Empty error message
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=1"
    End

    It 'handles all empty strings'
      add_validation_result "empty1" "" "error" "" ""
      add_validation_result "empty2" "" "error" "" ""
      add_validation_result "empty3" "" "error" "" ""

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # All empty
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=3"
    End
  End

  # ========================================
  # Format: Unicode and International
  # ========================================
  Context 'format: unicode and international characters'
    It 'handles Japanese characters in app name'
      add_validation_result "app1" "アプリ" "error" "" "エラーメッセージ"
      add_validation_result "tool1" "ツール" "error" "" "エラー発生"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Japanese chars preserved
      The contents of file "$GITHUB_OUTPUT" should include "アプリ"
      The contents of file "$GITHUB_OUTPUT" should include "エラーメッセージ"
    End

    It 'handles emoji in app name'
      add_validation_result "app-rocket" "App🚀" "error" "" "Launch failed ⚡"
      add_validation_result "tool-bolt" "Tool⚡" "error" "" "Error ❌"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Emoji preserved
      The contents of file "$GITHUB_OUTPUT" should include "App🚀"
      The contents of file "$GITHUB_OUTPUT" should include "Tool⚡"
    End

    It 'handles accented characters'
      add_validation_result "cafe" "Café" "error" "" "Erreur café"
      add_validation_result "naive" "Naïve" "error" "" "Erreur naïve"
      add_validation_result "resume" "Résumé" "error" "" "Erreur résumé"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Accents preserved
      The contents of file "$GITHUB_OUTPUT" should include "Café"
      The contents of file "$GITHUB_OUTPUT" should include "Naïve"
      The contents of file "$GITHUB_OUTPUT" should include "Résumé"
    End
  End

  # ========================================
  # Output: File Operations
  # ========================================
  Context 'output: file operations'
    It 'creates output file if not exists'
      rm -f "$GITHUB_OUTPUT"
      add_validation_result "app" "App" "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure
      The path "$GITHUB_OUTPUT" should be exist
    End

    It 'appends to existing output file'
      echo "existing=content" > "$GITHUB_OUTPUT"
      add_validation_result "app" "App" "error" "" "Error message"

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Previous content preserved
      The contents of file "$GITHUB_OUTPUT" should include "existing=content"
      # New content added
      The contents of file "$GITHUB_OUTPUT" should include "status=error"
    End
  End

  # ========================================
  # Consistency: Multiple Calls
  # ========================================
  Context 'consistency: multiple invocations'
    check_consistency() {
      add_validation_result "app1" "App1" "error" "" "Error 1"
      add_validation_result "app2" "App2" "error" "" "Error 2"

      # First call (redirect stderr)
      output_validation_errors_json VALIDATION_RESULTS VALIDATED_APPS 2>/dev/null
      first_output=$(cat "$GITHUB_OUTPUT")

      # Clear and second call (redirect stderr)
      rm "$GITHUB_OUTPUT"
      touch "$GITHUB_OUTPUT"
      output_validation_errors_json VALIDATION_RESULTS VALIDATED_APPS 2>/dev/null
      second_output=$(cat "$GITHUB_OUTPUT")

      # Compare outputs
      test "$first_output" = "$second_output"
    }

    It 'produces identical output for same input (excluding stderr)'
      When call check_consistency
      The status should be success
    End
  End

  # ========================================
  # Performance: Large Data
  # ========================================
  Context 'performance: large data sets'
    It 'handles 500+ errors without error'
      # Create 500 errors
      for i in $(seq 1 500); do
        add_validation_result "app${i}" "Application${i}" "error" "" "Error message ${i}"
      done

      When call output_validation_errors_json VALIDATION_RESULTS
      The status should be failure

      # stderr: Header
      The stderr should include "=== Application validation failed ==="

      # Verify count
      The contents of file "$GITHUB_OUTPUT" should include "failed_count=500"
    End
  End
End
