#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/__tests__/system/setup-tool.system.spec.sh
# @(#) : ShellSpec system tests for setup-tool.sh — requires real network (RUN_SYSTEM_TESTS=1)
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash
# cspell:words rhysd actionlint RUNNER checksums

SCRIPT_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/setup-tool.sh"
Include "$SCRIPT_PATH"

# ─── Fixture constants

readonly _TOOL_NAME="actionlint"
readonly _TOOL_VERSION="1.7.7"
readonly _ARCH_SUFFIX="amd64"
readonly _DOWNLOAD_URL="https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_linux_amd64.tar.gz"
readonly _CHECKSUM_URL="https://github.com/rhysd/actionlint/releases/download/v1.7.7/actionlint_1.7.7_checksums.txt"

# ─── Internal Helpers

_system_temp_dir=""
_system_bin_dir=""

# Setup: create TEMP_DIR and BIN_DIR. No network calls — filesystem setup only.
# shellcheck disable=SC2329
_setup_system() {
  _system_temp_dir=$(mktemp -d)
  _system_bin_dir="${_system_temp_dir}/bin"
  mkdir -p "$_system_bin_dir"
}

# Teardown: remove temp dirs.
# shellcheck disable=SC2329
_teardown_system() {
  rm -rf "${_system_temp_dir:-}"
}

# ─── T-16: setup-tool.sh システムテスト ──────────────────────────────────────

BeforeAll '_setup_system'
AfterAll '_teardown_system'

Describe 'download_tool: real GitHub Releases download'
  Skip if "RUN_SYSTEM_TESTS is not set" [ -z "${RUN_SYSTEM_TESTS:-}" ]

  It "T-sts-nor-10: download_tool downloads actionlint.tar.gz from real URL"
    When run download_tool "$_DOWNLOAD_URL" "$_CHECKSUM_URL" "$_system_temp_dir" "$_TOOL_NAME"
    The file "${_system_temp_dir}/actionlint.tar.gz" should be exist
    The status should be success
  End

  It "T-sts-nor-11: download_tool downloads checksums.txt from real URL"
    The file "${_system_temp_dir}/checksums.txt" should be exist
  End
End

Describe 'verify_checksum: real tar.gz and checksums.txt'
  Skip if "RUN_SYSTEM_TESTS is not set" [ -z "${RUN_SYSTEM_TESTS:-}" ]

  It "T-sts-nor-12: verify_checksum passes for real tar.gz and checksums.txt"
    When call verify_checksum "$_TOOL_NAME" "$_TOOL_VERSION" "$_ARCH_SUFFIX" "$_system_temp_dir"
    The status should be success
  End
End

Describe 'extract_install: binary exists after extraction'
  Skip if "RUN_SYSTEM_TESTS is not set" [ -z "${RUN_SYSTEM_TESTS:-}" ]

  It "T-sts-nor-13: extract_install places actionlint binary in BIN_DIR"
    When call extract_install "$_TOOL_NAME" "$_system_temp_dir" "$_system_bin_dir"
    The file "${_system_bin_dir}/actionlint" should be exist
  End
End

Describe 'extract_install: installed binary is executable'
  Skip if "RUN_SYSTEM_TESTS is not set" [ -z "${RUN_SYSTEM_TESTS:-}" ]

  It "T-sts-nor-14: installed actionlint has executable permission"
    Skip if "not running on Linux CI" [ "${GITHUB_ACTIONS:-}" != "true" ]
    The file "${_system_bin_dir}/actionlint" should be executable
  End

  It "T-sts-nor-15: actionlint --version exits 0 and prints version string"
    Skip if "not running on Linux CI" [ "${GITHUB_ACTIONS:-}" != "true" ]
    When run "${_system_bin_dir}/actionlint" --version
    The status should be success
    The stdout should not be empty
  End
End
