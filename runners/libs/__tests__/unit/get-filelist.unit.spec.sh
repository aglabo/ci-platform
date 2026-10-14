#!/usr/bin/env bash
# src: ./runners/libs/__tests__/unit/get-filelist.unit.spec.sh
# @(#) : ShellSpec unit tests for get-filelist.lib.sh get_filelist filter handling
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/runners/libs/get-filelist.lib.sh"

# ─── Internal Helpers

# Creates the fixtures under _TEST_DIR.
#   .ignore             : allow-lists .hidden/ so rg lists it, as the repo's .gitignore does for .github/
#   .hidden/x/a.spec.sh : hidden path (rg output has no ./ prefix)
#   visible/b.spec.sh   : visible path (rg output gets ./ prefix)
_setup_env() {
  _TEST_DIR=$(mktemp -d)
  mkdir -p "${_TEST_DIR}/.hidden/x" "${_TEST_DIR}/visible"
  printf '%s\n' '!.hidden/' > "${_TEST_DIR}/.ignore"
  : > "${_TEST_DIR}/.hidden/x/a.spec.sh"
  : > "${_TEST_DIR}/visible/b.spec.sh"
}

# Removes the fixture directory.
_cleanup_env() {
  rm -rf "${_TEST_DIR}"
}

# ─── Tests

Describe 'get_filelist'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'

  Describe 'Then: Task T-01-01 - leading ./ in dir filters'
    It '[Normal] T-01-01-01: filter "./.hidden/x" -> ".hidden/x/a.spec.sh"'
      When call get_filelist "${_TEST_DIR}" "*.spec.sh" "./.hidden/x"
      The output should equal ".hidden/x/a.spec.sh"
    End

    It '[Normal] T-01-01-02: filter "./visible" -> "./visible/b.spec.sh"'
      When call get_filelist "${_TEST_DIR}" "*.spec.sh" "./visible"
      The output should equal "./visible/b.spec.sh"
    End

    It '[Normal] T-01-01-03: filter ".hidden/x" -> ".hidden/x/a.spec.sh"'
      When call get_filelist "${_TEST_DIR}" "*.spec.sh" ".hidden/x"
      The output should equal ".hidden/x/a.spec.sh"
    End
  End
End
