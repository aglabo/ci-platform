#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/_libs/__tests__/unit/install.unit.spec.sh
# @(#) : ShellSpec unit tests for extract_install()
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash

LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/install.lib.sh"
Include "$LIB_PATH"

# ─── Internal Helpers

_test_temp_dir=""
_test_bin_dir=""

# 正常系 + 冪等性テスト用
# shellcheck disable=SC2329
_setup_extract_ok() {
  _test_temp_dir=$(mktemp -d)
  _test_bin_dir=$(mktemp -d)
  echo "#!/bin/sh" > "${_test_temp_dir}/actionlint"
  chmod +x "${_test_temp_dir}/actionlint"
  (cd "$_test_temp_dir" && tar -czf actionlint.tar.gz actionlint && rm actionlint)
}

# T-11-02: バイナリ不在（別名ファイル）
# shellcheck disable=SC2329
_setup_extract_no_binary() {
  _test_temp_dir=$(mktemp -d)
  _test_bin_dir=$(mktemp -d)
  echo "README content" > "${_test_temp_dir}/README"
  (cd "$_test_temp_dir" && tar -czf actionlint.tar.gz README && rm README)
}

# T-11-03: 破損tar.gz
# shellcheck disable=SC2329
_setup_extract_corrupt() {
  _test_temp_dir=$(mktemp -d)
  _test_bin_dir=$(mktemp -d)
  echo "not a tarball" > "${_test_temp_dir}/actionlint.tar.gz"
}

# T-11-04: 冪等性（BIN_DIRに既存バイナリ）
# shellcheck disable=SC2329
_setup_extract_idempotent() {
  _test_temp_dir=$(mktemp -d)
  _test_bin_dir=$(mktemp -d)
  echo "old content" > "${_test_bin_dir}/actionlint"
  echo "#!/bin/sh" > "${_test_temp_dir}/actionlint"
  chmod +x "${_test_temp_dir}/actionlint"
  (cd "$_test_temp_dir" && tar -czf actionlint.tar.gz actionlint && rm actionlint)
}

# shellcheck disable=SC2329
_teardown_extract() {
  rm -rf "$_test_temp_dir" "$_test_bin_dir"
}

# ─── Tests

Describe 'Given: valid tar.gz containing actionlint binary'
  BeforeEach '_setup_extract_ok'
  AfterEach '_teardown_extract'

  Describe 'When: extract_install is called'
    Describe 'Then: Task T-ext-nor - Normal Cases'
      It "T-ext-nor-01: binary exists at \${_bin_dir}/actionlint"
        When call extract_install "actionlint" "$_test_temp_dir" "$_test_bin_dir"
        The file "${_test_bin_dir}/actionlint" should be exist
      End

      It "T-ext-nor-02: binary has permission 755"
        When call extract_install "actionlint" "$_test_temp_dir" "$_test_bin_dir"
        The file "${_test_bin_dir}/actionlint" should be executable
      End
    End
  End
End

Describe 'Given: tar.gz contains no actionlint binary (only README)'
  BeforeEach '_setup_extract_no_binary'
  AfterEach '_teardown_extract'

  Describe 'When: extract_install is called'
    Describe 'Then: Task T-ext-err - Binary Not Found'
      It "T-ext-err-01: stderr contains ::error:: and exit code is 4"
        When call extract_install "actionlint" "$_test_temp_dir" "$_test_bin_dir"
        The stderr should include "::error::"
        The status should equal 4
      End
    End
  End
End

Describe 'Given: tar.gz is corrupted (not a valid archive)'
  BeforeEach '_setup_extract_corrupt'
  AfterEach '_teardown_extract'

  Describe 'When: extract_install is called'
    Describe 'Then: Task T-ext-err - Tar Failure'
      It "T-ext-err-02: stderr contains ::error:: and exit code is 4"
        When call extract_install "actionlint" "$_test_temp_dir" "$_test_bin_dir"
        The stderr should include "::error::"
        The status should equal 4
      End
    End
  End
End

Describe 'Given: BIN_DIR already contains an existing actionlint binary'
  BeforeEach '_setup_extract_idempotent'
  AfterEach '_teardown_extract'

  Describe 'When: extract_install is called'
    Describe 'Then: Task T-ext-edg - Idempotency'
      It "T-ext-edg-01: overwrites existing binary and exits 0"
        When call extract_install "actionlint" "$_test_temp_dir" "$_test_bin_dir"
        The file "${_test_bin_dir}/actionlint" should be exist
        The status should be success
      End
    End
  End
End

# ─── T-12: cleanup() ────────────────────────────────────────────────────────

_test_temp_dir=""

# shellcheck disable=SC2329
_setup_cleanup() {
  _test_temp_dir=$(mktemp -d)
}

# shellcheck disable=SC2329
_setup_cleanup_nonexistent() {
  _test_temp_dir="/tmp/nonexistent_${$}_test_cleanup"
}

# shellcheck disable=SC2329
_teardown_cleanup() {
  rm -rf "$_test_temp_dir"
}

Describe 'Given: TEMP_DIR exists'
  BeforeEach '_setup_cleanup'
  AfterEach '_teardown_cleanup'
  Describe 'When: cleanup is called'
    Describe 'Then: Task T-cln-nor - Normal Cases'
      It "T-cln-nor-01: removes TEMP_DIR"
        When call cleanup "$_test_temp_dir"
        The directory "$_test_temp_dir" should not be exist
        The output should include "Cleanup completed"
      End
      It "T-cln-nor-02: outputs Cleanup completed to stdout"
        When call cleanup "$_test_temp_dir"
        The output should include "Cleanup completed"
      End
    End
  End
End

Describe 'Given: TEMP_DIR does not exist'
  BeforeEach '_setup_cleanup_nonexistent'
  AfterEach '_teardown_cleanup'
  Describe 'When: cleanup is called'
    Describe 'Then: Task T-cln-edg - Edge Cases'
      It "T-cln-edg-01: exits 0 even when TEMP_DIR does not exist (idempotent)"
        When call cleanup "$_test_temp_dir"
        The status should be success
        The output should include "Cleanup completed"
      End
    End
  End
End
