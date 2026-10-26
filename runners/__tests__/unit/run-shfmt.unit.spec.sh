#!/usr/bin/env bash
# src: ./runners/__tests__/unit/run-shfmt.unit.spec.sh
# @(#) : ShellSpec unit tests for run-shfmt.sh main()
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/runners/run-shfmt.sh"

# ─── Internal Helpers

# Creates the fixture directory (_TEST_DIR), the stub argument log (_STUB_LOG),
# and points PROJECT_ROOT at _TEST_DIR so main() changes into the fixture.
_setup_env() {
  _TEST_DIR=$(mktemp -d)
  _STUB_LOG=$(mktemp)
  PROJECT_ROOT="${_TEST_DIR}"
}

# Removes the fixture directory and the stub argument log.
_cleanup_env() {
  rm -rf "${_TEST_DIR}"
  rm -f "${_STUB_LOG}"
}

# Stub replacing shfmt: appends each argument to _STUB_LOG, one per line.
# main() calls shfmt in a subshell, so a file is used instead of a variable.
shfmt() {
  printf '%s\n' "$@" >> "${_STUB_LOG}"
}

# ─── Tests

Describe 'Given: explicit file arguments including a ShellSpec spec file'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with a.sh and a.spec.sh'
    Describe 'Then: Task T-03-01 - spec files are dropped before calling shfmt'
      It "[Normal] T-03-01-01: --list a.sh a.spec.sh -> shfmt -ln bash -i 2 -l -- a.sh"
        When call main --list a.sh a.spec.sh
        The status should equal 0
        The contents of file "${_STUB_LOG}" should equal "$(printf '%s\n' -ln bash -i 2 -l -- a.sh)"
      End

      It "[Normal] T-03-01-02: --format a.sh a.spec.sh -> shfmt -ln bash -i 2 -w -- a.sh"
        When call main --format a.sh a.spec.sh
        The status should equal 0
        The contents of file "${_STUB_LOG}" should equal "$(printf '%s\n' -ln bash -i 2 -w -- a.sh)"
      End
    End
  End

  Describe 'When: main is called with a directory argument'
    Describe 'Then: Task T-03-01 - directories are passed through unchanged'
      It "[Normal] T-03-01-03: --list runners -> shfmt -ln bash -i 2 -l -- runners"
        When call main --list runners
        The status should equal 0
        The contents of file "${_STUB_LOG}" should equal "$(printf '%s\n' -ln bash -i 2 -l -- runners)"
      End
    End
  End
End

Describe 'Given: boundary target lists'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with only spec files'
    Describe 'Then: Task T-03-02 - nothing is run'
      It "[Edge] T-03-02-01: --list a.spec.sh b/c.spec.sh -> shfmt not called, exit 0, no output"
        When call main --list a.spec.sh b/c.spec.sh
        The status should equal 0
        The output should equal ""
        The contents of file "${_STUB_LOG}" should equal ""
      End
    End
  End

  Describe 'When: main is called with no arguments'
    Describe 'Then: Task T-03-02 - the default target is the project root'
      It "[Edge] T-03-02-02: no arguments -> shfmt -ln bash -i 2 -l -- ."
        When call main
        The status should equal 0
        The contents of file "${_STUB_LOG}" should equal "$(printf '%s\n' -ln bash -i 2 -l -- .)"
      End
    End
  End
End
