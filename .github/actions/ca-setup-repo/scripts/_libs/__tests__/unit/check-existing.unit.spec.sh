#!/usr/bin/env bash
# src: .github/actions/ca-setup-repo/scripts/__tests__/unit/check-existing.unit.spec.sh
# @(#) : ShellSpec unit tests for check-existing.lib.sh
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-setup-repo/scripts/_libs/check-existing.lib.sh"

# ─── Internal Helpers

setup_env() {
  GITHUB_OUTPUT=$(mktemp)
  GITHUB_ENV=$(mktemp)
  _TEST_DIR=$(mktemp -d)
}

cleanup_env() {
  rm -f "${GITHUB_OUTPUT}" "${GITHUB_ENV}"
  rm -rf "${_TEST_DIR}"
}

# ─── Tests

Describe 'Given: path directory does not exist'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: check_existing is called'
    Describe 'Then: Task T-02-01 - skip=false is written to GITHUB_OUTPUT'
      It "T-02-01-01: skip=false in GITHUB_OUTPUT and REPO_LOCK_DIR in GITHUB_ENV"
        _non_existent="${_TEST_DIR}/non-existent"
        When call check_existing "owner/repo" "${_non_existent}"
        The status should equal 0
        The contents of file "${GITHUB_OUTPUT}" should include "skip=false"
        The contents of file "${GITHUB_ENV}" should include "REPO_LOCK_DIR="
      End
    End
  End
End

Describe 'Given: path exists and .repo matches input repo'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: check_existing is called with matching repo'
    Describe 'Then: Task T-02-02 - skip=true is written to GITHUB_OUTPUT'
      It "T-02-02-01: skip=true in GITHUB_OUTPUT"
        printf 'owner/repo@abc123' > "${_TEST_DIR}/.repo"
        When call check_existing "owner/repo" "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${GITHUB_OUTPUT}" should include "skip=true"
      End
    End
    Describe 'Then: Task T-02-06 - skip=true and REPO_LOCK_DIR in GITHUB_ENV'
      It "T-02-06-01: skip=true in GITHUB_OUTPUT and REPO_LOCK_DIR in GITHUB_ENV"
        printf 'owner/repo@abc123' > "${_TEST_DIR}/.repo"
        When call check_existing "owner/repo" "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${GITHUB_OUTPUT}" should include "skip=true"
        The contents of file "${GITHUB_ENV}" should include "REPO_LOCK_DIR="
      End
    End
  End
End

Describe 'Given: path exists but .repo is missing'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: check_existing is called'
    Describe 'Then: Task T-02-03 - error and exit 1'
      It "T-02-03-01: stderr contains ::error:: and exits 1"
        When run check_existing "owner/repo" "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: .repo contains a different repo'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: check_existing is called with mismatched repo'
    Describe 'Then: Task T-02-04 - error and exit 1'
      It "T-02-04-01: stderr contains ::error:: and exits 1"
        printf 'other/repo@abc123' > "${_TEST_DIR}/.repo"
        When run check_existing "owner/repo" "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: .repo.lock directory already exists'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'
  Describe 'When: check_existing is called'
    Describe 'Then: Task T-02-05 - lock conflict error and exit 1'
      It "T-02-05-01: stderr contains ::error:: and exits 1"
        mkdir "${_TEST_DIR}/.repo.lock"
        When run check_existing "owner/repo" "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

