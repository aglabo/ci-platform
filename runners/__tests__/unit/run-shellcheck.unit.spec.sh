#!/usr/bin/env bash
# src: ./runners/__tests__/unit/run-shellcheck.unit.spec.sh
# @(#) : ShellSpec unit tests for run-shellcheck.sh main()
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/runners/run-shellcheck.sh"

# ─── Internal Helpers

# Creates the fixture directory (_TEST_DIR) and the stub argument log (_STUB_LOG).
_setup_env() {
  _TEST_DIR=$(mktemp -d)
  _STUB_LOG=$(mktemp)
}

# Removes the fixture directory and the stub argument log.
_cleanup_env() {
  rm -rf "${_TEST_DIR}"
  rm -f "${_STUB_LOG}"
}

# Creates empty fixture files under _TEST_DIR, making parent directories.
# Arguments: $@ - paths relative to _TEST_DIR
_make_files() {
  local _rel
  for _rel in "$@"; do
    mkdir -p "$(dirname "${_TEST_DIR}/${_rel}")"
    : > "${_TEST_DIR}/${_rel}"
  done
}

# Stub replacing shellcheck: appends each argument to _STUB_LOG, one per line.
# main() calls shellcheck in a subshell, so a file is used instead of a variable.
shellcheck() {
  printf '%s\n' "$@" >> "${_STUB_LOG}"
}

# ─── Tests

Describe 'Given: a target directory with .sh files'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with the directory'
    Describe 'Then: Task T-01-01 - excluded directories are pruned, others are scanned'
      It "[Normal] T-01-01-01: <tmp>/node_modules/pkg/x.sh is not passed, <tmp>/a.sh is"
        _make_files "a.sh" "node_modules/pkg/x.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/a.sh"
        The contents of file "${_STUB_LOG}" should not include "${_TEST_DIR}/node_modules/pkg/x.sh"
      End

      It "[Normal] T-01-01-02: <tmp>/sub/node_modules/pkg/x.sh is not passed, <tmp>/a.sh is"
        _make_files "a.sh" "sub/node_modules/pkg/x.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/a.sh"
        The contents of file "${_STUB_LOG}" should not include "${_TEST_DIR}/sub/node_modules/pkg/x.sh"
      End

      It "[Normal] T-01-01-03: <tmp>/.tools/tool/y.sh is not passed, <tmp>/a.sh is"
        _make_files "a.sh" ".tools/tool/y.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/a.sh"
        The contents of file "${_STUB_LOG}" should not include "${_TEST_DIR}/.tools/tool/y.sh"
      End

      It "[Normal] T-01-01-04: <tmp>/a.sh is passed"
        _make_files "a.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/a.sh"
      End

      It "[Normal] T-01-01-05: <tmp>/lib/b.sh is passed"
        _make_files "lib/b.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/lib/b.sh"
      End
    End
  End
End

Describe 'Given: an unknown command-line option'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with --bogus'
    Describe 'Then: Task T-01-02 - option error without running shellcheck'
      It "[Error] T-01-02-01: returns 1, reports Unknown option, and does not call shellcheck"
        When call main --bogus
        The status should equal 1
        The stderr should include "Unknown option: --bogus"
        The contents of file "${_STUB_LOG}" should equal ""
      End
    End
  End
End

Describe 'Given: .sh files at the boundary of the exclusion patterns'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with the directory'
    Describe 'Then: Task T-01-03 - only */node_modules/* is excluded'
      It "[Edge] T-01-03-01: only <tmp>/node_modules/pkg/x.sh exists -> No .sh files found, shellcheck not called"
        _make_files "node_modules/pkg/x.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The stderr should include "No .sh files found."
        The contents of file "${_STUB_LOG}" should equal ""
      End

      It "[Edge] T-01-03-02: <tmp>/node_modules_backup/c.sh is passed"
        _make_files "node_modules_backup/c.sh"
        When call main "${_TEST_DIR}"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/node_modules_backup/c.sh"
      End
    End
  End

  Describe 'When: main is called with a file under node_modules'
    Describe 'Then: Task T-01-03 - exclusion applies only to directory scans'
      It "[Edge] T-01-03-03: <tmp>/node_modules/pkg/x.sh given as a file is passed"
        _make_files "node_modules/pkg/x.sh"
        When call main "${_TEST_DIR}/node_modules/pkg/x.sh"
        The status should equal 0
        The contents of file "${_STUB_LOG}" should include "${_TEST_DIR}/node_modules/pkg/x.sh"
      End
    End
  End
End
