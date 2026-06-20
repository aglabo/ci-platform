#!/usr/bin/env bash
# src: .github/actions/setup-tool-repo/scripts/__tests__/integration/setup-tool-repo.integration.spec.sh
# @(#) : ShellSpec integration tests for setup-tool-repo composite action
# shellcheck shell=bash

# cspell:words mytool agla

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool-repo/scripts/_libs/validate-inputs.lib.sh"
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool-repo/scripts/_libs/check-existing.lib.sh"
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool-repo/scripts/_libs/validate-repo-structure.lib.sh"
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool-repo/scripts/_libs/verify-and-add-path.lib.sh"

# ─── Internal Helpers

setup_env() {
  _TEST_DIR=$(mktemp -d)
  GITHUB_PATH=$(mktemp)
  GITHUB_ENV=$(mktemp)
  GITHUB_OUTPUT=$(mktemp)
  REPO_LOCK_DIR="${_TEST_DIR}/.repo.lock"
  mkdir "${REPO_LOCK_DIR}"
  SKIP_REPO="false"
  mkdir -p "${_TEST_DIR}/node_modules/.bin"
  mkdir -p "${_TEST_DIR}/bin"
  printf '#!/bin/bash\necho hello\n' > "${_TEST_DIR}/bin/mytool"
  touch "${_TEST_DIR}/pnpm-lock.yaml"
}

cleanup_env() {
  rm -f "${GITHUB_PATH}" "${GITHUB_ENV}" "${GITHUB_OUTPUT}"
  rm -rf "${_TEST_DIR}"
}

_run_integration_flow() {
  validate_inputs "owner/repo" "./tools/agla" "v1.0.0" || return 1
  validate_repo_structure "${_TEST_DIR}" || return 1
  verify_and_add_path "${_TEST_DIR}" "owner/repo" "abc123" || return 1
}

# ─── Tests

# T-05-01: [正常] 正常系統合フロー

Describe 'Given: valid inputs, pnpm-lock.yaml and bin/ exist, node_modules/.bin/ exists'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'

  Describe 'When: validate_inputs, validate_repo_structure, verify_and_add_path are called in sequence'
    Describe 'Then: Task T-05-01 - all libraries pass and GITHUB_PATH is updated'
      It "T-05-01-01: exits 0 and GITHUB_PATH contains bin/ path"
        When call _run_integration_flow
        The status should equal 0
        The contents of file "${GITHUB_PATH}" should include "${_TEST_DIR}/bin"
      End
    End
  End
End

# T-05-02: [異常] 異常系統合フロー

Describe 'Given: invalid repo format (no slash)'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'

  Describe 'When: validate_inputs is called with repo="agla-doc-tools"'
    Describe 'Then: Task T-05-02-01 - validate_inputs fails before subsequent scripts'
      It "T-05-02-01: exits 1 and stderr contains ::error::"
        When run validate_inputs "agla-doc-tools" "./tools/agla" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: path/.repo contains different repo (other/repo@abc123)'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'

  Describe 'When: check_existing is called with repo="owner/repo" but .repo has "other/repo@abc123"'
    Describe 'Then: Task T-05-02-02 - check_existing exits 1 on repo conflict'
      It "T-05-02-02: exits 1 and stderr contains ::error::"
        printf 'other/repo@abc123' > "${_TEST_DIR}/.repo"
        When run check_existing "owner/repo" "${_TEST_DIR}"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End
