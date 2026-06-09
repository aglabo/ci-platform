#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/__tests__/functional/setup-tool.functional.spec.sh
# @(#) : ShellSpec functional integration tests for setup-tool.sh
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash
# cspell:words rhysd

SCRIPT_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/setup-tool.sh"
Include "$SCRIPT_PATH"

# ─── Internal Helpers
#
# Fixture helpers (_setup_*): create temp dirs, real tar.gz + checksums, set runner env vars.
# Mock helpers (_mock_curl_*): override `curl` via `export -f` to serve fixture files without network.
# Cleanup helper (_teardown_integration): remove all temp dirs and unset env vars after each test.
# Subprocess helper (_run_script_check_cleanup): run script as a real subprocess so EXIT trap fires,
#   then read TEMP_DIR path from GITHUB_ENV file and assert it was deleted.

_test_runner_temp=""
_test_fixture_dir=""
_test_github_env_file=""

# Build a dummy executable binary and pack it into a tar.gz inside <dir>.
# shellcheck disable=SC2329
_create_binary_tarball() {
  local _dir="$1"
  local _tarball="$2"
  printf '#!/bin/sh\necho "actionlint v1.7.7"\n' > "${_dir}/actionlint"
  chmod +x "${_dir}/actionlint"
  (cd "$_dir" && tar -czf "$_tarball" actionlint)
}

# Compute the real sha256 of <tarball_name> and write it to <checksum_file> in <dir>.
# shellcheck disable=SC2329
_write_checksum() {
  local _dir="$1"
  local _tarball="$2"
  local _checksum_file="$3"
  local _hash
  _hash=$(sha256sum "${_dir}/${_tarball}" | awk '{print $1}')
  printf '%s  %s\n' "$_hash" "$_tarball" > "${_dir}/${_checksum_file}"
}

# Create a complete fixture: binary tarball + real sha256 checksum file in <dir>.
# shellcheck disable=SC2329
_create_fixture() {
  local _dir="$1"
  local _tarball="$2"
  local _checksum_file="$3"
  _create_binary_tarball "$_dir" "$_tarball"
  _write_checksum "$_dir" "$_tarball" "$_checksum_file"
}

# Setup: amd64 normal flow — valid binary, tar.gz, real sha256 checksum, amd64 runner env.
# shellcheck disable=SC2329
_setup_integration_ok() {
  _test_runner_temp=$(mktemp -d)
  _test_fixture_dir=$(mktemp -d)

  _create_fixture "$_test_fixture_dir" "actionlint_1.7.7_linux_amd64.tar.gz" "checksums.txt"

  # env: GitHub Actions runner environment
  # shellcheck disable=SC2034
  RUNNER_TEMP="$_test_runner_temp"
  # shellcheck disable=SC2034
  RUNNER_ARCH="X64"
  # shellcheck disable=SC2034
  GITHUB_ENV="/dev/null"
  # shellcheck disable=SC2034
  GITHUB_PATH="/dev/null"
}

# Setup: override GITHUB_ENV with a real file so setup_dirs() writes TEMP_DIR= to it.
# Required by cleanup verification tests that need to read TEMP_DIR after subprocess exit.
# shellcheck disable=SC2329
_setup_real_github_env() {
  _test_github_env_file=$(mktemp)
  export RUNNER_TEMP="$_test_runner_temp"
  export RUNNER_ARCH GITHUB_PATH
  export GITHUB_ENV="$_test_github_env_file"
}

# Mock: curl serves amd64 tar.gz + checksums.txt from fixture dir; API JSON lists both assets.
# shellcheck disable=SC2329
_mock_curl_integration() {
  curl() {
    local _output="" _prev=""
    for _arg in "$@"; do
      if [[ "$_prev" == "-o" ]]; then _output="$_arg"; fi
      _prev="$_arg"
    done
    if [[ -n "$_output" ]]; then
      if [[ "$_output" == *".tar.gz" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz" "$_output"
      elif [[ "$_output" == *"checksums.txt" ]]; then
        cp "${_test_fixture_dir}/checksums.txt" "$_output"
      fi
      return 0
    fi
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# Mock: curl always fails (exit 1) — simulates network error or API unavailability.
# shellcheck disable=SC2329
_mock_curl_fail_integration() {
  curl() { return 1; }
  export -f curl
}

# Setup: arm64 flow — linux_arm64.tar.gz fixture with real sha256, RUNNER_ARCH=ARM64.
# shellcheck disable=SC2329
_setup_integration_arm64() {
  _test_runner_temp=$(mktemp -d)
  _test_fixture_dir=$(mktemp -d)

  _create_fixture "$_test_fixture_dir" "actionlint_1.7.7_linux_arm64.tar.gz" "checksums.txt"

  # shellcheck disable=SC2034
  RUNNER_TEMP="$_test_runner_temp"
  # shellcheck disable=SC2034
  RUNNER_ARCH="ARM64"
  # shellcheck disable=SC2034
  GITHUB_ENV="/dev/null"
  # shellcheck disable=SC2034
  GITHUB_PATH="/dev/null"
}

# Mock: curl serves arm64 tar.gz + checksums.txt; API JSON lists arm64 asset.
# shellcheck disable=SC2329
_mock_curl_arm64() {
  curl() {
    local _output="" _prev=""
    for _arg in "$@"; do
      if [[ "$_prev" == "-o" ]]; then _output="$_arg"; fi
      _prev="$_arg"
    done
    if [[ -n "$_output" ]]; then
      if [[ "$_output" == *".tar.gz" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_linux_arm64.tar.gz" "$_output"
      elif [[ "$_output" == *"checksums.txt" ]]; then
        cp "${_test_fixture_dir}/checksums.txt" "$_output"
      fi
      return 0
    fi
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_arm64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_arm64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# Setup: versioned checksums fallback — no plain checksums.txt; only actionlint_1.7.7_checksums.txt.
# Verifies resolve_assets() falls back to the versioned filename when checksums.txt is absent.
# shellcheck disable=SC2329
_setup_versioned_checksums() {
  _test_runner_temp=$(mktemp -d)
  _test_fixture_dir=$(mktemp -d)

  _create_fixture "$_test_fixture_dir" "actionlint_1.7.7_linux_amd64.tar.gz" "actionlint_1.7.7_checksums.txt"

  # shellcheck disable=SC2034
  RUNNER_TEMP="$_test_runner_temp"
  # shellcheck disable=SC2034
  RUNNER_ARCH="X64"
  # shellcheck disable=SC2034
  GITHUB_ENV="/dev/null"
  # shellcheck disable=SC2034
  GITHUB_PATH="/dev/null"
}

# Mock: curl serves amd64 tar.gz + versioned checksums file; API JSON lists actionlint_1.7.7_checksums.txt (no plain checksums.txt).
# shellcheck disable=SC2329
_mock_curl_versioned_checksums() {
  curl() {
    local _output="" _prev=""
    for _arg in "$@"; do
      if [[ "$_prev" == "-o" ]]; then _output="$_arg"; fi
      _prev="$_arg"
    done
    if [[ -n "$_output" ]]; then
      if [[ "$_output" == *".tar.gz" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz" "$_output"
      elif [[ "$_output" == *"checksums.txt" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_checksums.txt" "$_output"
      fi
      return 0
    fi
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"actionlint_1.7.7_checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# Setup: checksum mismatch — tar.gz is valid but checksums.txt contains a deliberate wrong hash.
# Verifies verify_checksum() detects the mismatch and exits 3 without installing the binary.
# shellcheck disable=SC2329
_setup_checksum_mismatch() {
  _test_runner_temp=$(mktemp -d)
  _test_fixture_dir=$(mktemp -d)

  _create_binary_tarball "$_test_fixture_dir" "actionlint_1.7.7_linux_amd64.tar.gz"

  printf 'deadbeef0000000000000000000000000000000000000000000000000000000000  actionlint_1.7.7_linux_amd64.tar.gz\n' > "${_test_fixture_dir}/checksums.txt"

  # shellcheck disable=SC2034
  RUNNER_TEMP="$_test_runner_temp"
  # shellcheck disable=SC2034
  RUNNER_ARCH="X64"
  # shellcheck disable=SC2034
  GITHUB_ENV="/dev/null"
  # shellcheck disable=SC2034
  GITHUB_PATH="/dev/null"
}

# Mock: curl serves valid tar.gz + bad-hash checksums.txt; API JSON lists both assets.
# shellcheck disable=SC2329
_mock_curl_bad_checksum() {
  curl() {
    local _output="" _prev=""
    for _arg in "$@"; do
      if [[ "$_prev" == "-o" ]]; then _output="$_arg"; fi
      _prev="$_arg"
    done
    if [[ -n "$_output" ]]; then
      if [[ "$_output" == *".tar.gz" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz" "$_output"
      elif [[ "$_output" == *"checksums.txt" ]]; then
        cp "${_test_fixture_dir}/checksums.txt" "$_output"
      fi
      return 0
    fi
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# Setup: corrupt tar.gz — file content is not a valid archive; checksums.txt holds the REAL sha256
# of the corrupt file so verify_checksum() passes, then extract_install() fails with exit 4.
# shellcheck disable=SC2329
_setup_corrupt_tar() {
  _test_runner_temp=$(mktemp -d)
  _test_fixture_dir=$(mktemp -d)

  printf 'this is not a tar file\n' > "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz"

  local _hash
  _hash=$(sha256sum "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz" | awk '{print $1}')
  printf '%s  actionlint_1.7.7_linux_amd64.tar.gz\n' "$_hash" > "${_test_fixture_dir}/checksums.txt"

  # shellcheck disable=SC2034
  RUNNER_TEMP="$_test_runner_temp"
  # shellcheck disable=SC2034
  RUNNER_ARCH="X64"
  # shellcheck disable=SC2034
  GITHUB_ENV="/dev/null"
  # shellcheck disable=SC2034
  GITHUB_PATH="/dev/null"
}

# Mock: curl serves corrupt tar.gz + its real-sha256 checksums.txt; API JSON lists both assets.
# shellcheck disable=SC2329
_mock_curl_corrupt_tar() {
  curl() {
    local _output="" _prev=""
    for _arg in "$@"; do
      if [[ "$_prev" == "-o" ]]; then _output="$_arg"; fi
      _prev="$_arg"
    done
    if [[ -n "$_output" ]]; then
      if [[ "$_output" == *".tar.gz" ]]; then
        cp "${_test_fixture_dir}/actionlint_1.7.7_linux_amd64.tar.gz" "$_output"
      elif [[ "$_output" == *"checksums.txt" ]]; then
        cp "${_test_fixture_dir}/checksums.txt" "$_output"
      fi
      return 0
    fi
    printf '{"assets":[\n'
    printf '  {"name":"actionlint_1.7.7_linux_amd64.tar.gz","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"},\n'
    printf '  {"name":"checksums.txt","browser_download_url":"https://github.com/rhysd/actionlint/releases/download/v1.7.7/checksums.txt"}\n'
    printf ']}\n200'
    return 0
  }
  export -f curl
}

# Helper: run script as subprocess so EXIT trap fires, then assert TEMP_DIR was deleted.
# Reads TEMP_DIR path from GITHUB_ENV file written by setup_dirs() during the subprocess run.
# Requires _setup_real_github_env to have been called beforehand (GITHUB_ENV must be a real file).
# shellcheck disable=SC2329
_run_script_check_cleanup() {
  bash "$SCRIPT_PATH" "rhysd/actionlint" "1.7.7" >/dev/null 2>&1 || true
  local _temp_dir_path
  _temp_dir_path=$(grep '^TEMP_DIR=' "$_test_github_env_file" | cut -d= -f2- | tr -d '\r' | head -1)
  if [[ -d "$_temp_dir_path" ]]; then
    echo "exists: $_temp_dir_path" >&2
    return 1
  fi
  echo "cleaned"
}

# Teardown: remove all temp dirs and fixture dirs; unset mock curl and runner env vars.
# shellcheck disable=SC2329
_teardown_integration() {
  rm -rf "$_test_runner_temp" "$_test_fixture_dir"
  rm -f "$_test_github_env_file"
  _test_github_env_file=""
  unset -f curl 2>/dev/null || true
  unset RUNNER_TEMP RUNNER_ARCH GITHUB_ENV GITHUB_PATH BIN_DIR TEMP_DIR 2>/dev/null || true
}

# ─── T-15: setup-tool.sh 統合テスト ──────────────────────────────────────────

Describe 'Given: valid fixtures and mocked curl'
  BeforeEach '_setup_integration_ok'
  BeforeEach '_mock_curl_integration'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-nor - Normal Cases'
      It "T-sts-nor-04: binary actionlint exists in BIN_DIR and is executable"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should be executable
      End
      It "T-sts-nor-05: exits 0"
        When run main "rhysd/actionlint" "1.7.7"
        The status should be success
      End
      It "T-sts-nor-07: BIN_DIR exists after main() returns"
        When run main "rhysd/actionlint" "1.7.7"
        The directory "${_test_runner_temp}/bin" should be exist
      End
      It "T-sts-nor-08: v-prefixed version v1.7.7 normalizes and exits 0"
        When run main "rhysd/actionlint" "v1.7.7"
        The status should be success
      End
    End
  End

  Describe 'When: main is called with rhysd/actionlint 1.7.7 (cleanup verification)'
    BeforeEach '_setup_real_github_env'

    Describe 'Then: Task T-sts-nor - Trap Cleanup'
      It "T-sts-nor-06: TEMP_DIR is deleted after main() returns (trap cleanup)"
        When call _run_script_check_cleanup
        The output should equal "cleaned"
        The status should be success
      End
    End
  End
End

Describe 'Given: curl always fails'
  BeforeEach '_setup_integration_ok'
  BeforeEach '_mock_curl_fail_integration'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-err - Error Cases'
      It "T-sts-err-12: binary is not created and exit code is 2"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should not be exist
        The stderr should include "::error::"
        The status should equal 2
      End
    End
  End

  Describe 'When: main is called with rhysd/actionlint 1.7.7 (cleanup verification)'
    BeforeEach '_setup_real_github_env'

    Describe 'Then: Task T-sts-edg - Cleanup on Download Failure'
      It "T-sts-edg-03: TEMP_DIR deleted after download failure"
        When call _run_script_check_cleanup
        The output should equal "cleaned"
        The status should be success
      End
    End
  End
End

Describe 'Given: ARM64 fixtures and mocked curl'
  BeforeEach '_setup_integration_arm64'
  BeforeEach '_mock_curl_arm64'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-nor - ARM64 Cases'
      It "T-sts-nor-09: RUNNER_ARCH=ARM64 installs arm64 binary to BIN_DIR"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should be executable
        The status should be success
      End
    End
  End
End

Describe 'Given: versioned checksums fixture and mocked curl'
  BeforeEach '_setup_versioned_checksums'
  BeforeEach '_mock_curl_versioned_checksums'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-edg - Versioned Checksums Fallback'
      It "T-sts-edg-02: versioned checksums.txt fallback resolves and exits 0"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should be executable
        The status should be success
      End
    End
  End
End

Describe 'Given: checksum mismatch fixture and mocked curl'
  BeforeEach '_setup_checksum_mismatch'
  BeforeEach '_mock_curl_bad_checksum'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-err - Checksum Mismatch'
      It "T-sts-err-13: SHA256 mismatch — binary not in BIN_DIR, exit 3"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should not be exist
        The stderr should include "::error::"
        The status should equal 3
      End
    End
  End

  Describe 'When: main is called with rhysd/actionlint 1.7.7 (cleanup verification)'
    BeforeEach '_setup_real_github_env'

    Describe 'Then: Task T-sts-edg - Cleanup on Checksum Failure'
      It "T-sts-edg-04: TEMP_DIR deleted after checksum mismatch"
        When call _run_script_check_cleanup
        The output should equal "cleaned"
        The status should be success
      End
    End
  End
End

Describe 'Given: corrupt tar.gz fixture and mocked curl'
  BeforeEach '_setup_corrupt_tar'
  BeforeEach '_mock_curl_corrupt_tar'
  AfterEach '_teardown_integration'

  Describe 'When: main is called with rhysd/actionlint 1.7.7'
    Describe 'Then: Task T-sts-err - Corrupt tar.gz'
      It "T-sts-err-14: corrupt tar.gz — binary not in BIN_DIR, exit 4"
        When run main "rhysd/actionlint" "1.7.7"
        The file "${_test_runner_temp}/bin/actionlint" should not be exist
        The stderr should include "::error::"
        The status should equal 4
      End
    End
  End
End
