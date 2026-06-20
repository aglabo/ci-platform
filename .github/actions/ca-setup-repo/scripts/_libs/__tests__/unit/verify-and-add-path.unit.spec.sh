#!/usr/bin/env bash
# src: .github/actions/ca-setup-repo/scripts/__tests__/unit/verify-and-add-path.unit.spec.sh
# @(#) : ShellSpec unit tests for verify-and-add-path.lib.sh
# shellcheck shell=bash

# cspell:words mytool


Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-setup-repo/scripts/_libs/verify-and-add-path.lib.sh"

# ─── Internal Helpers

setup_env() {
  GITHUB_PATH=$(mktemp)
  GITHUB_ENV=$(mktemp)
  _TEST_DIR=$(mktemp -d)
  REPO_LOCK_DIR="${_TEST_DIR}/.repo.lock"
  mkdir "${REPO_LOCK_DIR}"
  SKIP_REPO="false"
}

cleanup_env() {
  rm -f "${GITHUB_PATH}" "${GITHUB_ENV}"
  rm -rf "${_TEST_DIR}"
}

# ─── Tests

# T-04-01: [正常] skip=false（新規チェックアウト）

Describe 'Given: node_modules/.bin/ exists, bin/ has executable file, SKIP_REPO=false'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-01 - GITHUB_PATH appended, .repo written, lock released'
      It "T-04-01-01: exits 0, bin/ in GITHUB_PATH, .repo has owner/repo@sha, lock removed"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        printf '#!/bin/bash\necho hello\n' > "${_TEST_DIR}/bin/mytool"
        chmod +x "${_TEST_DIR}/bin/mytool"
        SKIP_REPO="false"
        When call verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The status should equal 0
        The contents of file "${GITHUB_PATH}" should include "${_TEST_DIR}/bin"
        The contents of file "${_TEST_DIR}/.repo" should equal "owner/repo@abc123"
        The path "${_TEST_DIR}/.repo.lock" should not be exist
      End
    End
  End
End

# T-04-02: [正常] skip=true（既存チェックアウト再利用）

Describe 'Given: node_modules/.bin/ exists, bin/ has executable file, SKIP_REPO=true'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-02 - GITHUB_PATH appended, .repo NOT written, lock released'
      It "T-04-02-01: exits 0, bin/ in GITHUB_PATH, no .repo file, lock removed"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        printf '#!/bin/bash\necho hello\n' > "${_TEST_DIR}/bin/mytool"
        SKIP_REPO="true"
        When call verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The status should equal 0
        The contents of file "${GITHUB_PATH}" should include "${_TEST_DIR}/bin"
        The path "${_TEST_DIR}/.repo" should not be exist
        The path "${_TEST_DIR}/.repo.lock" should not be exist
      End
    End
  End
End

# T-04-03: [異常] post-install 検証の失敗ケース

Describe 'Given: node_modules/.bin/ does not exist'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-03-01 - R-015 error, exit 1, lock remains'
      It "T-04-03-01: stderr contains ::error:: and exits 1, .repo.lock still exists"
        mkdir -p "${_TEST_DIR}/bin"
        printf '#!/bin/bash\necho hello\n' > "${_TEST_DIR}/bin/mytool"
        When run verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The stderr should include "::error::"
        The status should equal 1
        The path "${_TEST_DIR}/.repo.lock" should be exist
      End
    End
  End
End

Describe 'Given: node_modules/.bin/ exists, bin/ is empty directory'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-03-02 - R-016 error, exit 1, lock remains'
      It "T-04-03-02: stderr contains ::error:: and exits 1, .repo.lock still exists"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        When run verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The stderr should include "::error::"
        The status should equal 1
        The path "${_TEST_DIR}/.repo.lock" should be exist
      End
    End
  End
End

Describe 'Given: node_modules/.bin/ exists, bin/ has non-executable file (touch)'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-03-03 - R-017 error, exit 1, lock remains'
      It "T-04-03-03: stderr contains ::error:: and exits 1, .repo.lock still exists"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        touch "${_TEST_DIR}/bin/noexec_tool"
        When run verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The stderr should include "::error::"
        The status should equal 1
        The path "${_TEST_DIR}/.repo.lock" should be exist
      End
    End
  End
End

# T-04-05: [エッジケース] node_modules/.bin/ が空ディレクトリでも pass する

Describe 'Given: node_modules/.bin/ exists but is empty, bin/ has executable file'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-05-01 - R-015 checks directory existence only, exit 0'
      It "T-04-05-01: exits 0 (node_modules/.bin/ empty dir is acceptable)"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        printf '#!/bin/bash\necho hello\n' > "${_TEST_DIR}/bin/mytool"
        When call verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The status should equal 0
      End
    End
  End
End

# T-04-06: [エッジケース] bin/ 配下にシンボリックリンクのみ存在する場合

Describe 'Given: bin/ has only a symlink pointing to an executable target'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-06-01 - symlink with exec target passes R-017, exit 0'
      It "T-04-06-01: exits 0 (symlink to executable file)"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        _real="${_TEST_DIR}/real_exec"
        printf '#!/bin/bash\necho hello\n' > "${_real}"
        MSYS=winsymlinks:nativestrict ln -s "${_real}" "${_TEST_DIR}/bin/mytool"
        When call verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: bin/ has only a symlink pointing to a non-executable target (touch)'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: verify_and_add_path is called'
    Describe 'Then: Task T-04-06-02 - symlink with non-exec target fails R-017, exit 1'
      It "T-04-06-02: stderr contains ::error:: and exits 1 (symlink to non-executable file)"
        mkdir -p "${_TEST_DIR}/node_modules/.bin"
        mkdir -p "${_TEST_DIR}/bin"
        _real="${_TEST_DIR}/real_noexec"
        touch "${_real}"
        MSYS=winsymlinks:nativestrict ln -s "${_real}" "${_TEST_DIR}/bin/mytool"
        When run verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End
