#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/output-validation-success-json.spec.sh
# ShellSpec tests for output_validation_success_json function
# JSON-based version of output-validation-success.spec.sh
# Tests JSON data structures from add_validation_result

Describe 'output_validation_success_json()'
  # Get absolute path to script
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-apps.sh"

  # Source the script to load functions
  Include "$SCRIPT_PATH"

  # Setup and teardown for each test
  BeforeEach 'setup_test'
  setup_test() {
    GITHUB_OUTPUT_FILE=$(mktemp)
    declare -ga VALIDATION_RESULTS=()
    VALIDATION_INDEX=0
  }

  AfterEach 'cleanup_test'
  cleanup_test() {
    rm -f "$GITHUB_OUTPUT_FILE"
  }

  # ========================================
  # Normal Cases: Single Validation
  # ========================================
  Context 'normal case: single validation'
    It 'outputs complete success information to stderr and GITHUB_OUTPUT'
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # stderr: Header
      The stderr should include "=== Application validation passed ==="

      # GITHUB_OUTPUT: status field
      The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"

      # GITHUB_OUTPUT: message field with multiline EOF
      The contents of file "$GITHUB_OUTPUT_FILE" should include "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Applications validated:"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Git git version 2.52.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "MULTILINE_EOF"

      # GITHUB_OUTPUT: validated_apps field
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=Git"

      # GITHUB_OUTPUT: count fields
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=1"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
    End
  End

  # ========================================
  # Normal Cases: Multiple Validations
  # ========================================
  Context 'normal case: multiple validations'
    It 'outputs all validated apps with correct formatting'
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""
      add_validation_result "curl" "curl" "success" "curl 8.0.1" ""
      add_validation_result "gh" "gh" "success" "gh version 2.40.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # stderr: Header
      The stderr should include "=== Application validation passed ==="

      # GITHUB_OUTPUT: All apps in message field with indentation
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Git git version 2.52.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  curl curl 8.0.1"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  gh gh version 2.40.0"

      # GITHUB_OUTPUT: Count fields
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=3"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
    End

    It 'includes all app names in validated_apps (comma-separated)'
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""
      add_validation_result "curl" "curl" "success" "curl 8.0.1" ""
      add_validation_result "gh" "gh" "success" "gh version 2.40.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: validated_apps contains all apps (comma-separated)
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=Git,curl,gh"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=3"
    End
  End

  # ========================================
  # Normal Cases: Message Formatting
  # ========================================
  Context 'normal case: message formatting'
    It 'indents app entries with exactly 2 spaces in GITHUB_OUTPUT'
      add_validation_result "app1" "App1" "success" "version 1.0" ""
      add_validation_result "app2" "App2" "success" "version 2.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Entries indented with exactly 2 spaces (not 3+)
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App1 version 1.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App2 version 2.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "   App1"
    End

    It 'separates app name and version with single space'
      add_validation_result "testapp" "TestApp" "success" "test version 3.5.1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Single space between app name and version
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  TestApp test version 3.5.1"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "  TestApp  test"
    End
  End

  # ========================================
  # Normal Cases: Complex Version Strings
  # ========================================
  Context 'normal case: complex version strings'
    It 'handles version strings with multiple words'
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""
      add_validation_result "node" "Node.js" "success" "Node.js v18.16.0 (release)" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Full version strings preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Git git version 2.52.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Node.js Node.js v18.16.0 (release)"

      # GITHUB_OUTPUT: Counts
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
    End

    It 'handles version strings with special characters'
      add_validation_result "tool-1" "tool-1" "success" "version 1.0-beta" ""
      add_validation_result "tool.v2" "tool.v2" "success" "v2.3.4-rc1 (build-2024)" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Special characters preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  tool-1 version 1.0-beta"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  tool.v2 v2.3.4-rc1 (build-2024)"
    End
  End

  # ========================================
  # Edge Cases: Empty Arrays
  # ========================================
  Context 'edge case: empty arrays'
    It 'handles empty validated arrays gracefully'
      # No add_validation_result calls - empty VALIDATION_RESULTS

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # stderr: Header still present
      The stderr should include "=== Application validation passed ==="

      # GITHUB_OUTPUT: Zero validated
      The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"

      # GITHUB_OUTPUT: Empty validated_apps
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps="

      # GITHUB_OUTPUT: Message still formatted correctly
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Applications validated:"
    End
  End

  # ========================================
  # Edge Cases: Large Number of Validations
  # ========================================
  Context 'edge case: many validations'
    It 'handles 10+ validations correctly'
      # Create 15 validated apps
      for i in $(seq 1 15); do
        add_validation_result "app${i}" "App${i}" "success" "version ${i}.0.0" ""
      done

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Correct count
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=15"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"

      # Verify all apps are present in output (sample check)
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App1 version 1.0.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App15 version 15.0.0"

      # GITHUB_OUTPUT: All apps in comma-separated list
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*validated_apps=*App1*"
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*validated_apps=*App15*"
    End
  End

  # ========================================
  # Edge Cases: Long Version Strings
  # ========================================
  Context 'edge case: long version strings'
    It 'handles very long version strings'
      local long_version="GNU bash, version 5.2.37(1)-release (x86_64-pc-linux-gnu) built with extra modules and debugging symbols"
      add_validation_result "bash" "Bash" "success" "$long_version" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Full long version preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Bash $long_version"
    End
  End

  # ========================================
  # Edge Cases: App Names with Special Characters
  # ========================================
  Context 'edge case: app names with special characters'
    It 'handles app names with dots, hyphens, and slashes'
      add_validation_result "my-app.v2" "my-app.v2" "success" "v2.1.0" ""
      add_validation_result "node" "Node.js" "success" "v18.0.0" ""
      add_validation_result "tool/bin" "tool/bin" "success" "version 1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: All special characters preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  my-app.v2 v2.1.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Node.js v18.0.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  tool/bin version 1.0"

      # GITHUB_OUTPUT: validated_apps contains all (order preserved)
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*validated_apps=*my-app.v2*"
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*validated_apps=*Node.js*"
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*validated_apps=*tool/bin*"
    End

    It 'handles app names with spaces'
      add_validation_result "git-cli" "Git CLI Tool" "success" "version 2.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Spaces in app name preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Git CLI Tool version 2.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=Git CLI Tool"
    End
  End

  # ========================================
  # Edge Cases: Multiline EOF Delimiter
  # ========================================
  Context 'edge case: MULTILINE_EOF delimiter'
    It 'uses correct EOF delimiter format in GITHUB_OUTPUT'
      add_validation_result "testapp" "TestApp" "success" "version 1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # GITHUB_OUTPUT: Verify EOF delimiter structure
      The line 2 of contents of file "$GITHUB_OUTPUT_FILE" should equal "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Applications validated:"
      # Verify closing delimiter exists
      The contents of file "$GITHUB_OUTPUT_FILE" should include "MULTILINE_EOF"
    End
  End

  # ========================================
  # Invariants: Always Returns Success
  # ========================================
  Context 'invariant: exit status'
    It 'always returns exit status 0 (success)'
      add_validation_result "anyapp" "AnyApp" "success" "version 1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should equal 0
    End

    It 'returns success even with empty arrays'
      # Empty VALIDATION_RESULTS

      When call output_validation_success_json VALIDATION_RESULTS
      The status should equal 0
    End

    It 'returns success with large number of validations'
      for i in $(seq 1 100); do
        add_validation_result "app${i}" "App${i}" "success" "v${i}.0" ""
      done

      When call output_validation_success_json VALIDATION_RESULTS
      The status should equal 0
    End
  End

  # ========================================
  # Invariants: Required Output Fields
  # ========================================
  Context 'invariant: required GITHUB_OUTPUT fields'
    It 'always includes all required fields'
      add_validation_result "testapp" "TestApp" "success" "version 1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # All 5 required fields must be present
      The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "message<<MULTILINE_EOF"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps="
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count="
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
    End

    It 'always sets failed_count to 0'
      add_validation_result "app1" "App1" "success" "v1" ""
      add_validation_result "app2" "App2" "success" "v2" ""
      add_validation_result "app3" "App3" "success" "v3" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # failed_count is always 0 for success case
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "failed_count=1"
    End
  End

  # ========================================
  # Invariants: Output to Stderr
  # ========================================
  Context 'invariant: stderr output'
    It 'always outputs header to stderr'
      add_validation_result "app" "App" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success
      The stderr should include "=== Application validation passed ==="
    End

    It 'outputs to stderr even with empty arrays'
      # Empty VALIDATION_RESULTS

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success
      The stderr should include "=== Application validation passed ==="
    End
  End

  # ========================================
  # Invariants: No Stdout Output
  # ========================================
  Context 'invariant: no stdout output'
    It 'does not output to stdout (only GITHUB_OUTPUT file)'
      add_validation_result "testapp" "TestApp" "success" "version 1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success
      The stdout should be blank
    End
  End

  # ========================================
  # Regression: Comma Separation
  # ========================================
  Context 'regression: comma separation in validated_apps'
    It 'uses commas without spaces to separate app names'
      add_validation_result "app1" "App1" "success" "v1" ""
      add_validation_result "app2" "App2" "success" "v2" ""
      add_validation_result "app3" "App3" "success" "v3" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Comma separation without spaces
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=App1,App2,App3"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "validated_apps=App1, App2"
    End
  End

  # ========================================
  # Regression: Order Preservation
  # ========================================
  Context 'regression: order preservation'
    It 'preserves app order in both message and validated_apps'
      add_validation_result "zebra" "Zebra" "success" "z1" ""
      add_validation_result "alpha" "Alpha" "success" "a1" ""
      add_validation_result "beta" "Beta" "success" "b1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Order preserved in message (not alphabetically sorted)
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*Zebra z1*Alpha a1*Beta b1*"

      # Order preserved in validated_apps
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=Zebra,Alpha,Beta"
    End
  End

  # ========================================
  # Boundary: Single Character Values
  # ========================================
  Context 'boundary: single character values'
    It 'handles single-character app names'
      add_validation_result "a" "a" "success" "v1" ""
      add_validation_result "b" "b" "success" "v2" ""
      add_validation_result "c" "c" "success" "v3" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Single chars preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=a,b,c"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  a v1"
    End

    It 'handles single-character versions'
      add_validation_result "app1" "App1" "success" "1" ""
      add_validation_result "app2" "App2" "success" "2" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Single char versions preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App1 1"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App2 2"
    End
  End

  # ========================================
  # Boundary: Maximum Values
  # ========================================
  Context 'boundary: maximum values'
    It 'handles 100+ validations'
      # Create 150 validated apps
      for i in $(seq 1 150); do
        add_validation_result "app${i}" "App${i}" "success" "v${i}.0.0" ""
      done

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Verify count
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=150"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"

      # Spot check first and last
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App1 v1.0.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App150 v150.0.0"
    End

    It 'handles very long app name (200 characters)'
      local long_name="$(printf 'A%.0s' {1..200})"
      add_validation_result "longapp" "$long_name" "success" "v1.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Long name preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=${long_name}"
    End
  End

  # ========================================
  # Security: Special Characters
  # ========================================
  Context 'security: special characters in values'
    It 'rejects newlines in app name (security: prevent log injection)'
      # Security: app_name with control characters should be rejected
      When call add_validation_result "app-newline" "App"$'\n'"Name" "success" "v1" ""
      The status should be failure
      The stderr should include "::error::Invalid app_name"
      The stderr should include "contains control characters"
    End

    It 'handles quotes in app name'
      add_validation_result "app-quotes1" "App\"With\"Quotes" "success" "v1" ""
      add_validation_result "app-quotes2" "App'With'Quotes" "success" "v2" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Quotes should be preserved or escaped properly
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
    End

    It 'handles dollar signs in version string'
      add_validation_result "app" "App" "success" 'version $1.0 (build $100)' ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Dollar signs should not be expanded
      The contents of file "$GITHUB_OUTPUT_FILE" should include '$1.0'
      The contents of file "$GITHUB_OUTPUT_FILE" should include '$100'
    End

    It 'handles backticks in version string'
      add_validation_result "app" "App" "success" 'version `1.0` (cmd: `date`)' ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Backticks should not be executed
      The contents of file "$GITHUB_OUTPUT_FILE" should include '`1.0`'
      The contents of file "$GITHUB_OUTPUT_FILE" should include '`date`'
    End

    It 'handles semicolons and pipes in version'
      add_validation_result "app" "App" "success" 'v1.0; echo "injection" | cat' ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Shell metacharacters should not be executed
      The contents of file "$GITHUB_OUTPUT_FILE" should include 'v1.0; echo'
    End
  End

  # ========================================
  # Format: Whitespace Handling
  # ========================================
  Context 'format: whitespace handling'
    It 'handles leading whitespace in app name'
      add_validation_result "leading" "  LeadingSpace" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Leading space preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=  LeadingSpace"
    End

    It 'handles trailing whitespace in app name'
      add_validation_result "trailing" "TrailingSpace  " "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Trailing space preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=TrailingSpace  "
    End

    It 'handles multiple consecutive spaces in app name'
      add_validation_result "spaces" "App    With    Spaces" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Multiple spaces preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "App    With    Spaces"
    End

    It 'rejects tab characters in app name (security: prevent log injection)'
      # Security: app_name with control characters should be rejected
      When call add_validation_result "tab" "App"$'\t'"WithTab" "success" "v1" ""
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
      add_validation_result "empty" "" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Empty app name case
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=1"
    End

    It 'handles empty string in version'
      add_validation_result "app" "App" "success" "" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Empty version string
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App "
    End

    It 'handles all empty strings'
      add_validation_result "empty1" "" "success" "" ""
      add_validation_result "empty2" "" "success" "" ""
      add_validation_result "empty3" "" "success" "" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # All empty
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=3"
    End
  End

  # ========================================
  # Format: Unicode and International
  # ========================================
  Context 'format: unicode and international characters'
    It 'handles Japanese characters in app name'
      add_validation_result "app1" "アプリ" "success" "バージョン1.0" ""
      add_validation_result "tool1" "ツール" "success" "v2.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Japanese chars preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "アプリ"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "バージョン1.0"
    End

    It 'handles emoji in app name'
      add_validation_result "app-rocket" "App🚀" "success" "v1.0" ""
      add_validation_result "tool-bolt" "Tool⚡" "success" "v2.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Emoji preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "App🚀"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Tool⚡"
    End

    It 'handles accented characters'
      add_validation_result "cafe" "Café" "success" "v1" ""
      add_validation_result "naive" "Naïve" "success" "v2" ""
      add_validation_result "resume" "Résumé" "success" "v3" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Accents preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Café"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Naïve"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "Résumé"
    End
  End

  # ========================================
  # Output: File Permissions
  # ========================================
  Context 'output: file operations'
    It 'creates output file if not exists'
      rm -f "$GITHUB_OUTPUT_FILE"
      add_validation_result "app" "App" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success
      The path "$GITHUB_OUTPUT_FILE" should be exist
    End

    It 'appends to existing output file'
      echo "existing=content" > "$GITHUB_OUTPUT_FILE"
      add_validation_result "app" "App" "success" "v1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Previous content preserved
      The contents of file "$GITHUB_OUTPUT_FILE" should include "existing=content"
      # New content added
      The contents of file "$GITHUB_OUTPUT_FILE" should include "status=success"
    End
  End

  # ========================================
  # Consistency: Multiple Calls
  # ========================================
  Context 'consistency: multiple invocations'
    It 'produces identical output for same input (excluding stderr)'
      add_validation_result "app1" "App1" "success" "v1" ""
      add_validation_result "app2" "App2" "success" "v2" ""

      # First call (redirect stderr)
      output_validation_success_json VALIDATION_RESULTS 2>/dev/null
      local first_output=$(cat "$GITHUB_OUTPUT_FILE")

      # Clear and second call (redirect stderr)
      rm "$GITHUB_OUTPUT_FILE"
      touch "$GITHUB_OUTPUT_FILE"
      output_validation_success_json VALIDATION_RESULTS 2>/dev/null
      local second_output=$(cat "$GITHUB_OUTPUT_FILE")

      # Outputs should be identical
      When call test "$first_output" = "$second_output"
      The status should be success
    End
  End

  # ========================================
  # Performance: Large Data
  # ========================================
  Context 'performance: large data sets'
    It 'handles 500+ validations without error'
      # Create 500 validated apps
      for i in $(seq 1 500); do
        add_validation_result "app${i}" "Application${i}" "success" "version${i}.0.0" ""
      done

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Verify count
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=500"
    End
  End

  # ========================================
  # Stderr: Output Verification
  # ========================================
  Context 'stderr: complete output verification'
    It 'outputs only header to stderr (no app details)'
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""
      add_validation_result "curl" "curl" "success" "curl 8.0.1" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Stderr should only contain header
      The stderr should equal "=== Application validation passed ==="

      # App details should NOT be in stderr
      The stderr should not include "Git git version"
      The stderr should not include "curl curl"
    End
  End

  # ========================================
  # JSON-Specific: Mixed Success/Error Entries
  # ========================================
  Context 'JSON-specific: mixed success and error entries'
    It 'filters only success entries from mixed results'
      # Add success entries (should be processed)
      add_validation_result "git" "Git" "success" "git version 2.52.0" ""
      add_validation_result "curl" "curl" "success" "curl 8.0.1" ""

      # Add error entries (should be ignored)
      add_validation_result "gh" "gh" "error" "" "gh is not installed"
      add_validation_result "node" "Node.js" "error" "" "Node.js version too old"

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # stderr: Header only (no error mentions)
      The stderr should equal "=== Application validation passed ==="

      # GITHUB_OUTPUT: Only success apps
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  Git git version 2.52.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  curl curl 8.0.1"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "gh is not installed"
      The contents of file "$GITHUB_OUTPUT_FILE" should not include "Node.js version too old"

      # GITHUB_OUTPUT: Only success count
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=2"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"

      # GITHUB_OUTPUT: validated_apps contains only success apps
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=Git,curl"
    End
  End

  # ========================================
  # JSON-Specific: Order Preservation
  # ========================================
  Context 'JSON-specific: order preservation'
    It 'processes successes in array order (sequential index)'
      # Add successes in specific order
      add_validation_result "app1" "App1" "success" "v1.0" ""
      add_validation_result "app2" "App2" "success" "v2.0" ""
      add_validation_result "app3" "App3" "success" "v3.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # Order preserved in message
      The contents of file "$GITHUB_OUTPUT_FILE" should match pattern "*App1 v1.0*App2 v2.0*App3 v3.0*"

      # Order preserved in validated_apps
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps=App1,App2,App3"
    End
  End

  # ========================================
  # JSON-Specific: Index Gaps
  # ========================================
  Context 'JSON-specific: non-sequential indices'
    It 'handles validation results with gaps in indices'
      # Add results with non-sequential indices (e.g., after filtering)
      VALIDATION_INDEX=0
      add_validation_result "app1" "App1" "success" "v1.0" ""
      VALIDATION_INDEX=2  # Skip index 1
      add_validation_result "app3" "App3" "success" "v3.0" ""
      VALIDATION_INDEX=5  # Skip indices 3, 4
      add_validation_result "app6" "App6" "success" "v6.0" ""

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # All success entries processed
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App1 v1.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App3 v3.0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "  App6 v6.0"

      # Correct count (3 successes)
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=3"
    End
  End

  # ========================================
  # JSON-Specific: Empty Success After Error
  # ========================================
  Context 'JSON-specific: empty success list'
    It 'handles all-error validation results'
      # Add only error entries
      add_validation_result "app1" "App1" "error" "" "Error 1"
      add_validation_result "app2" "App2" "error" "" "Error 2"

      When call output_validation_success_json VALIDATION_RESULTS
      The status should be success

      # No success entries
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_count=0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "failed_count=0"
      The contents of file "$GITHUB_OUTPUT_FILE" should include "validated_apps="
    End
  End
End
