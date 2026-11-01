#!/usr/bin/env bash
# src: ./runners/__tests__/unit/run-actionlint.unit.spec.sh
# @(#) : ShellSpec unit tests for run-actionlint.sh main()
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/runners/run-actionlint.sh"

# ─── Internal Helpers

# Creates the fixture directory (_TEST_DIR), the stub argument log (_STUB_LOG),
# and resets the stub exit code (_STUB_RC) to 0.
# Points PROJECT_ROOT at _TEST_DIR so the repository's configs/jactionlint.yaml is not found.
_setup_env() {
  _TEST_DIR=$(mktemp -d)
  PROJECT_ROOT="${_TEST_DIR}"
  _STUB_LOG=$(mktemp)
  _STUB_RC=0
}

# Creates the repository config configs/jactionlint.yaml under PROJECT_ROOT (_TEST_DIR).
_create_local_config() {
  mkdir -p "${_TEST_DIR}/configs"
  : > "${_TEST_DIR}/configs/jactionlint.yaml"
}

# Removes the fixture directory and the stub argument log.
_cleanup_env() {
  rm -rf "${_TEST_DIR}"
  rm -f "${_STUB_LOG}"
}

# Stub replacing jactionlint: appends each argument to _STUB_LOG, one per line,
# and returns _STUB_RC.
jactionlint() {
  printf '%s\n' "$@" >> "${_STUB_LOG}"
  return "${_STUB_RC}"
}

# ─── Tests

Describe 'Given: XDG_CONFIG_HOME points to a config directory'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called'
    Describe 'Then: Task T-02-01 - config file under XDG_CONFIG_HOME is passed'
      It "[Normal] T-02-01-01: XDG_CONFIG_HOME=<tmp>/xdg -> --config-file <tmp>/xdg/jactionlint/jactionlint.yaml"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        HOME="${_TEST_DIR}/home"
        When call main
        The status should equal 0
        The line 1 of contents of file "${_STUB_LOG}" should equal "--config-file"
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/xdg/jactionlint/jactionlint.yaml"
      End
    End

    Describe 'Then: Task T-02-02 - arguments are forwarded after the config option'
      It "[Normal] T-02-02-01: main a.yml -> --config-file <config> a.yml"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main a.yml
        The status should equal 0
        The lines of contents of file "${_STUB_LOG}" should equal 3
        The line 1 of contents of file "${_STUB_LOG}" should equal "--config-file"
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/xdg/jactionlint/jactionlint.yaml"
        The line 3 of contents of file "${_STUB_LOG}" should equal "a.yml"
      End

      It "[Normal] T-02-02-02: main -color a.yml b.yml -> arguments forwarded in order"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main -color a.yml b.yml
        The status should equal 0
        The lines of contents of file "${_STUB_LOG}" should equal 5
        The line 3 of contents of file "${_STUB_LOG}" should equal "-color"
        The line 4 of contents of file "${_STUB_LOG}" should equal "a.yml"
        The line 5 of contents of file "${_STUB_LOG}" should equal "b.yml"
      End
    End
  End
End

Describe 'Given: jactionlint exits with a non-zero status'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: main is called with a.yml'
    Describe 'Then: Task T-02-03 - the exit status is propagated unchanged'
      It "[Error] T-02-03-01: jactionlint returns 3 -> main returns 3"
        _STUB_RC=3
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main a.yml
        The status should equal 3
        The line 3 of contents of file "${_STUB_LOG}" should equal "a.yml"
      End
    End
  End
End

Describe 'Given: boundary values for config resolution and arguments'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: XDG_CONFIG_HOME is unset or empty'
    Describe 'Then: Task T-02-04 - config falls back to HOME/.config'
      It "[Edge] T-02-04-01: XDG_CONFIG_HOME unset -> <tmp>/home/.config/jactionlint/jactionlint.yaml"
        unset XDG_CONFIG_HOME
        HOME="${_TEST_DIR}/home"
        When call main
        The status should equal 0
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/home/.config/jactionlint/jactionlint.yaml"
      End

      It "[Edge] T-02-04-02: XDG_CONFIG_HOME=\"\" -> <tmp>/home/.config/jactionlint/jactionlint.yaml"
        XDG_CONFIG_HOME=""
        HOME="${_TEST_DIR}/home"
        When call main
        The status should equal 0
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/home/.config/jactionlint/jactionlint.yaml"
      End
    End
  End

  Describe 'When: main is called with boundary arguments'
    Describe 'Then: Task T-02-04 - arguments are forwarded as given'
      It "[Edge] T-02-04-03: no arguments -> only the two config arguments, no unbound variable error"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main
        The status should equal 0
        The stderr should equal ""
        The lines of contents of file "${_STUB_LOG}" should equal 2
        The line 1 of contents of file "${_STUB_LOG}" should equal "--config-file"
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/xdg/jactionlint/jactionlint.yaml"
      End

      It "[Edge] T-02-04-04: main \"my flow.yml\" -> forwarded as a single argument"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main "my flow.yml"
        The status should equal 0
        The lines of contents of file "${_STUB_LOG}" should equal 3
        The line 3 of contents of file "${_STUB_LOG}" should equal "my flow.yml"
      End
    End
  End
End

Describe 'Given: a repository config exists under PROJECT_ROOT'
  BeforeEach '_setup_env' '_create_local_config'
  AfterEach '_cleanup_env'
  Describe 'When: main is called'
    Describe 'Then: Task T-02-05 - the repository config takes priority'
      It "[Normal] T-02-05-01: <tmp>/configs/jactionlint.yaml exists -> --config-file <tmp>/configs/jactionlint.yaml"
        XDG_CONFIG_HOME="${_TEST_DIR}/xdg"
        When call main a.yml
        The status should equal 0
        The lines of contents of file "${_STUB_LOG}" should equal 3
        The line 1 of contents of file "${_STUB_LOG}" should equal "--config-file"
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/configs/jactionlint.yaml"
        The line 3 of contents of file "${_STUB_LOG}" should equal "a.yml"
      End

      It "[Edge] T-02-05-02: XDG_CONFIG_HOME unset -> --config-file <tmp>/configs/jactionlint.yaml"
        unset XDG_CONFIG_HOME
        HOME="${_TEST_DIR}/home"
        When call main
        The status should equal 0
        The line 2 of contents of file "${_STUB_LOG}" should equal "${_TEST_DIR}/configs/jactionlint.yaml"
      End
    End
  End
End
