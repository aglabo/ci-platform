#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/__tests__/unit/setup-tool.unit.spec.sh
# @(#) : ShellSpec unit tests for setup-tool.sh orchestrator
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash

SCRIPT_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-setup-tool/scripts/setup-tool.sh"
Include "$SCRIPT_PATH"

# ─── Internal Helpers

_CALL_LOG_FILE=""

# shellcheck disable=SC2329
_mock_all_ok() {
  _CALL_LOG_FILE=$(mktemp)
  # shellcheck disable=SC2034
  BIN_DIR="/tmp/bin"
  # shellcheck disable=SC2034
  TEMP_DIR="/tmp/tmp_test"
  export _CALL_LOG_FILE
  normalize_version() { echo "normalize_version" >> "$_CALL_LOG_FILE"; echo "1.7.7"; return 0; }
  export -f normalize_version
  validate_symbol() { return 0; }
  export -f validate_symbol
  validate_repo() { return 0; }
  export -f validate_repo
  validate_version() { return 0; }
  export -f validate_version
  setup_dirs() { echo "setup_dirs" >> "$_CALL_LOG_FILE"; return 0; }
  export -f setup_dirs
  detect_arch() { echo "detect_arch" >> "$_CALL_LOG_FILE"; echo "amd64"; return 0; }
  export -f detect_arch
  build_url() { echo "https://api.github.com/repos/rhysd/actionlint/releases/tags/v1.7.7"; return 0; }
  export -f build_url
  resolve_assets() { echo "resolve_assets" >> "$_CALL_LOG_FILE"; printf "https://dl/actionlint.tar.gz\nhttps://dl/checksums.txt\namd64\n"; return 0; }
  export -f resolve_assets
  download_tool() { echo "download_tool" >> "$_CALL_LOG_FILE"; return 0; }
  export -f download_tool
  verify_checksum() { echo "verify_checksum" >> "$_CALL_LOG_FILE"; return 0; }
  export -f verify_checksum
  extract_install() { echo "extract_install" >> "$_CALL_LOG_FILE"; return 0; }
  export -f extract_install
  cleanup() { return 0; }
  export -f cleanup
}

# shellcheck disable=SC2329
_teardown_mock_all_ok() {
  rm -f "$_CALL_LOG_FILE"
}

# shellcheck disable=SC2329
_run_main_and_dump_log() {
  main "rhysd/actionlint" "1.7.7"
  cat "$_CALL_LOG_FILE"
}

# (no setup needed — args passed directly to main)

# shellcheck disable=SC2329
_mock_resolve_assets_fail() {
  _mock_all_ok
  resolve_assets() { return 2; }
  export -f resolve_assets
}

# shellcheck disable=SC2329
_mock_verify_checksum_fail() {
  _mock_all_ok
  verify_checksum() { return 3; }
  export -f verify_checksum
}

# shellcheck disable=SC2329
_mock_download_fail_with_cleanup_tracker() {
  _mock_all_ok
  download_tool() { return 2; }
  export -f download_tool
  cleanup() { echo "cleanup_was_called"; }
  export -f cleanup
}

# ─── Tests

Describe 'Given: all lib functions succeed'
  BeforeEach '_mock_all_ok'
  AfterEach '_teardown_mock_all_ok'

  Describe 'When: main is called'
    Describe 'Then: Task T-sts-nor - Normal Cases'
      It "T-sts-nor-01: functions called in correct order"
        When call _run_main_and_dump_log
        The output line 1 should equal "normalize_version"
        The output line 2 should equal "setup_dirs"
        The output line 3 should equal "detect_arch"
        The output line 4 should equal "resolve_assets"
        The output line 5 should equal "download_tool"
        The output line 6 should equal "verify_checksum"
        The output line 7 should equal "extract_install"
      End

      It "T-sts-nor-02: exits 0"
        When call main "rhysd/actionlint" "1.7.7"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: repo argument has no slash (invalid format)'
  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Input Validation Failure'
      It "T-sts-err-01: stderr contains ::error:: and exit code is 1"
        When run main "invalidrepo" "1.7.7"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: tool-version argument is non-semver (latest)'
  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Input Validation Failure'
      It "T-sts-err-02: stderr contains version error and exit code is 1"
        When run main "rhysd/actionlint" "latest"
        The stderr should include "Invalid version format"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: repo owner contains invalid characters (dot/underscore not allowed in owner)'
  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Input Validation Failure'
      It "T-sts-err-03: repo with path traversal is rejected with ::error:: and exit 1"
        When run main "../evil/path" "1.7.7"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: repo argument has more than one slash'
  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Input Validation Failure'
      It "T-sts-err-04: repo with two slashes is rejected with ::error:: and exit 1"
        When run main "owner/repo/extra" "1.7.7"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: repo owner starts with a hyphen'
  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Input Validation Failure'
      It "T-sts-err-05: owner starting with hyphen is rejected with ::error:: and exit 1"
        When run main "-owner/repo" "1.7.7"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: repo is a valid mixed-case GitHub repo (Microsoft/vscode)'
  BeforeEach '_mock_all_ok'
  AfterEach '_teardown_mock_all_ok'

  Describe 'When: main is called'
    Describe 'Then: Task T-sts-nor - Valid repo passes validation'
      It "T-sts-nor-03: mixed-case owner/repo is accepted and exits 0"
        When call main "Microsoft/vscode" "1.7.7"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: resolve_assets fails with exit 2'
  BeforeEach '_mock_resolve_assets_fail'
  AfterEach '_teardown_mock_all_ok'

  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Mid-step Failure'
      It "T-sts-err-06: propagates exit code 2"
        When run main "rhysd/actionlint" "1.7.7"
        The status should equal 2
      End
    End
  End
End

Describe 'Given: verify_checksum fails with exit 3'
  BeforeEach '_mock_verify_checksum_fail'
  AfterEach '_teardown_mock_all_ok'

  Describe 'When: main is run'
    Describe 'Then: Task T-sts-err - Mid-step Failure'
      It "T-sts-err-07: propagates exit code 3"
        When run main "rhysd/actionlint" "1.7.7"
        The status should equal 3
      End
    End
  End
End

Describe 'Given: download_tool fails with exit 2'
  BeforeEach '_mock_download_fail_with_cleanup_tracker'

  # shellcheck disable=SC2329
  _run_main_with_exit() { main "rhysd/actionlint" "1.7.7"; exit $?; }

  Describe 'When: main is run (subprocess for EXIT trap)'
    Describe 'Then: Task T-sts-edg - Trap Cleanup'
      It "T-sts-edg-01: cleanup runs even when download_tool fails"
        When run _run_main_with_exit
        The output should include "cleanup_was_called"
        The status should equal 2
      End
    End
  End
End
