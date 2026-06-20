#!/usr/bin/env bash
# src: .github/actions/setup-tool-repo/scripts/__tests__/unit/validate-repo-structure.unit.spec.sh
# @(#) : ShellSpec unit tests for validate-repo-structure.lib.sh
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool-repo/scripts/_libs/validate-repo-structure.lib.sh"

# ─── Internal Helpers

setup_dir() { _TEST_DIR=$(mktemp -d); }
cleanup_dir() { rm -rf "${_TEST_DIR}"; }

# ─── Tests

Describe 'Given: pnpm-lock.yaml and bin/ both exist'
  BeforeEach 'setup_dir'
  AfterEach 'cleanup_dir'
  Describe 'When: validate_repo_structure is called'
    Describe 'Then: Task T-03-01 - valid structure is accepted'
      It "T-03-01-01: exits 0"
        touch "${_TEST_DIR}/pnpm-lock.yaml"
        mkdir "${_TEST_DIR}/bin"
        When call validate_repo_structure "${_TEST_DIR}"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: pnpm-lock.yaml does not exist'
  BeforeEach 'setup_dir'
  AfterEach 'cleanup_dir'
  Describe 'When: validate_repo_structure is called'
    Describe 'Then: Task T-03-02 - missing pnpm-lock.yaml is rejected'
      It "T-03-02-01: stderr contains ::error:: and exits 1"
        mkdir "${_TEST_DIR}/bin"
        When run validate_repo_structure "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: bin/ directory does not exist'
  BeforeEach 'setup_dir'
  AfterEach 'cleanup_dir'
  Describe 'When: validate_repo_structure is called'
    Describe 'Then: Task T-03-03 - missing bin/ is rejected'
      It "T-03-03-01: stderr contains ::error:: and exits 1"
        touch "${_TEST_DIR}/pnpm-lock.yaml"
        When run validate_repo_structure "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End
