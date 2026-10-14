#!/usr/bin/env bash
# src: ./runners/libs/__tests__/unit/init-vars.unit.spec.sh
# @(#) : ShellSpec unit tests for init-vars.lib.sh PROJECT_ROOT resolution
# shellcheck shell=bash

# The lib is NOT Included: it has a readonly double-source guard and honors
# PROJECT_ROOT from env, so every case sources it in a fresh child process.

# ─── Internal Helpers

# Path of the real lib under test.
_LIB="${SHELLSPEC_PROJECT_ROOT}/runners/libs/init-vars.lib.sh"

# Child-process body: cd to $1, source the lib $2, print the resolved PROJECT_ROOT.
# shellcheck disable=SC2016 # expanded by the child shell, not here
_CHILD_SCRIPT='cd "$1" && . "$2" && printf "%s\n" "$PROJECT_ROOT"'

# Child-process prefix replacing git with a stub that always fails (128); used by T-01-02-01.
_GIT_FAIL_STUB='git() { return 128; }; '

# Creates the fixtures under _TEST_DIR and resolves the expected roots.
#   other/ : a foreign git repo used as the caller's cwd
#   plain/ : a non-git directory
#   proj/  : a non-git project holding a copy of the lib at runners/libs/
#   repo/  : a git repo (no commits) holding a lib copy nested at a/b/runners/libs/,
#            so its git toplevel (repo/) differs from the lib's ../.. (repo/a/b/)
_setup_env() {
  _TEST_DIR=$(mktemp -d)
  mkdir -p "${_TEST_DIR}/other" "${_TEST_DIR}/plain" "${_TEST_DIR}/proj/runners/libs"
  mkdir -p "${_TEST_DIR}/repo/a/b/runners/libs"
  git -C "${_TEST_DIR}/other" init -q
  git -C "${_TEST_DIR}/repo" init -q
  _PROJ_LIB="${_TEST_DIR}/proj/runners/libs/init-vars.lib.sh"
  cp "${_LIB}" "${_PROJ_LIB}"
  _NESTED_LIB="${_TEST_DIR}/repo/a/b/runners/libs/init-vars.lib.sh"
  cp "${_LIB}" "${_NESTED_LIB}"
  _NESTED_GIT_ROOT=$(git -C "${_TEST_DIR}/repo" rev-parse --show-toplevel)
  _NESTED_FALLBACK=$(cd "${_TEST_DIR}/repo/a/b" && pwd)
  _CI_ROOT=$(git -C "${SHELLSPEC_PROJECT_ROOT}" rev-parse --show-toplevel)
  _OTHER_ROOT=$(git -C "${_TEST_DIR}/other" rev-parse --show-toplevel)
  _CI_FALLBACK=$(cd "${SHELLSPEC_PROJECT_ROOT}" && pwd)
  _PROJ_ROOT=$(cd "${_TEST_DIR}/proj" && pwd)
}

# Removes the fixture directory.
_cleanup_env() {
  rm -rf "${_TEST_DIR}"
}

# Sources a lib in a fresh child process with PROJECT_ROOT and the guard unset,
# and prints the resolved PROJECT_ROOT.
# Arguments: $1 - cwd of the child process, $2 - lib path
_resolve_root() {
  env -u PROJECT_ROOT -u _INIT_VARS_LIB_SH \
    bash -c "${_CHILD_SCRIPT}" _ "$1" "$2"
}

# Same as _resolve_root, but with git replaced by _GIT_FAIL_STUB,
# forcing the ../.. fallback.
# Arguments: $1 - cwd of the child process, $2 - lib path
_resolve_root_git_fails() {
  env -u PROJECT_ROOT -u _INIT_VARS_LIB_SH \
    bash -c "${_GIT_FAIL_STUB}${_CHILD_SCRIPT}" _ "$1" "$2"
}

# Same as _resolve_root, but with PROJECT_ROOT preset in the child's env.
# Arguments: $1 - cwd of the child process, $2 - lib path, $3 - PROJECT_ROOT value
_resolve_root_with() {
  env -u _INIT_VARS_LIB_SH PROJECT_ROOT="$3" \
    bash -c "${_CHILD_SCRIPT}" _ "$1" "$2"
}

# ─── Tests

Describe 'Given: init-vars.lib.sh sourced in a fresh process'
  BeforeEach '_setup_env'
  AfterEach '_cleanup_env'
  Describe 'When: PROJECT_ROOT is resolved by the git lookup'
    Describe 'Then: Task T-01-01 - git lookup is anchored to the lib location'
      It "[Normal] T-01-01-01: cwd=<tmp>/other (foreign git repo) -> ci-platform root"
        When call _resolve_root "${_TEST_DIR}/other" "${_LIB}"
        The output should equal "${_CI_ROOT}"
        The output should not equal "${_OTHER_ROOT}"
      End

      It "[Normal] T-01-01-02: cwd=ci-platform root -> ci-platform root"
        When call _resolve_root "${SHELLSPEC_PROJECT_ROOT}" "${_LIB}"
        The output should equal "${_CI_ROOT}"
      End

      It "[Normal] T-01-01-04: cwd=<tmp>/other (foreign git repo) -> PROJECT_ROOT is a single line"
        When call _resolve_root "${_TEST_DIR}/other" "${_LIB}"
        The lines of output should equal 1
      End

      It "[Normal] T-01-01-05: lib copy in <tmp>/repo/a/b/runners/libs (git repo <tmp>/repo), cwd=<tmp>/other -> <tmp>/repo toplevel, not ../.."
        When call _resolve_root "${_TEST_DIR}/other" "${_NESTED_LIB}"
        The output should equal "${_NESTED_GIT_ROOT}"
        The output should not equal "${_NESTED_FALLBACK}"
        The output should not equal "${_OTHER_ROOT}"
      End
    End

    Describe 'Then: Task T-01-03 - a non-git caller cwd does not affect the lookup'
      It "[Edge] T-01-03-03: cwd=<tmp>/plain (non-git) -> ci-platform root"
        When call _resolve_root "${_TEST_DIR}/plain" "${_LIB}"
        The output should equal "${_CI_ROOT}"
      End
    End
  End

  Describe 'When: PROJECT_ROOT is preset in the environment'
    Describe 'Then: Task T-01-01 - explicit PROJECT_ROOT overrides the git lookup'
      It "[Normal] T-01-01-03: PROJECT_ROOT=/explicit/override, cwd=<tmp>/other -> /explicit/override"
        When call _resolve_root_with "${_TEST_DIR}/other" "${_LIB}" "/explicit/override"
        The output should equal "/explicit/override"
      End
    End

    Describe 'Then: Task T-01-03 - an empty PROJECT_ROOT is treated as unset'
      It "[Edge] T-01-03-02: PROJECT_ROOT='' (empty), cwd=<tmp>/other -> ci-platform root"
        When call _resolve_root_with "${_TEST_DIR}/other" "${_LIB}" ""
        The output should equal "${_CI_ROOT}"
        The output should not equal "${_OTHER_ROOT}"
      End
    End
  End

  Describe 'When: the git lookup fails'
    Describe 'Then: Task T-01-02 - PROJECT_ROOT falls back to the lib grandparent'
      It "[Error] T-01-02-01: git stub returns 128, cwd=<tmp>/other -> ci-platform root via ../.."
        When call _resolve_root_git_fails "${_TEST_DIR}/other" "${_LIB}"
        The output should equal "${_CI_FALLBACK}"
        The output should not equal "${_OTHER_ROOT}"
      End
    End
  End

  Describe 'When: the lib lives outside any git work tree'
    Describe 'Then: Task T-01-03 - fallback is not hijacked by the caller cwd repo'
      It "[Edge] T-01-03-01: lib copy in non-git <tmp>/proj, cwd=<tmp>/other -> <tmp>/proj"
        When call _resolve_root "${_TEST_DIR}/other" "${_PROJ_LIB}"
        The output should equal "${_PROJ_ROOT}"
        The output should not equal "${_OTHER_ROOT}"
      End
    End
  End
End
