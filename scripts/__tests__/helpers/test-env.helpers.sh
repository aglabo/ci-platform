#!/usr/bin/env bash
# Test environment setup and teardown helpers

setup_test_env() {
  # Create temporary test environment
  export TEST_TMPDIR="${SHELLSPEC_TMPDIR:-/tmp}/run-specs-test.$$"
  mkdir -p "$TEST_TMPDIR/fake-project"/{.tools/shellspec,scripts/__tests__}

  # Export test project paths
  export PROJECT_ROOT="$TEST_TMPDIR/fake-project"
  export SHELLSPEC="$TEST_TMPDIR/fake-project/.tools/shellspec/shellspec"

  # Create mock ShellSpec binary (default behavior)
  create_mock_shellspec

  # Create minimal .shellspec config
  create_shellspec_config

  # Save original directory
  ORIGINAL_DIR="$(pwd)"
  export ORIGINAL_DIR
}

teardown_test_env() {
  # Clean up temporary directory
  if [[ -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
  unset TEST_TMPDIR PROJECT_ROOT SHELLSPEC ORIGINAL_DIR
}
