#!/usr/bin/env bash
# src: .github/actions/ca-run-secretlint/scripts/__tests__/functional/run-secretlint.functional.spec.sh
# @(#) : functional tests for run-secretlint.sh (pnpm is stubbed on PATH)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Module: composite-action/run-secretlint (test_scope T-RSL-RUN)
# Target: ca-run-secretlint/scripts/run-secretlint.sh

_RSL_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-run-secretlint/scripts/run-secretlint.sh"
_RSL_STUB_DIR=""

##
# Create a stub `pnpm` that prints each argv item as "ARG:<item>" on stdout
# and exits with $STUB_PNPM_EXIT (default 0).
_rsl_stub_setup() {
  _RSL_STUB_DIR="$(mktemp -d)"
  cat >"${_RSL_STUB_DIR}/pnpm" <<'STUB'
#!/usr/bin/env bash
for _a in "$@"; do printf 'ARG:%s\n' "$_a"; done
exit "${STUB_PNPM_EXIT:-0}"
STUB
  chmod +x "${_RSL_STUB_DIR}/pnpm"
}

_rsl_stub_cleanup() {
  [ -n "$_RSL_STUB_DIR" ] && rm -rf "$_RSL_STUB_DIR"
  _RSL_STUB_DIR=""
}

##
# Run the script with the stub first on PATH.
# @arg $1 version  @arg $2 stub exit code (default 0)
_rsl_run() {
  PATH="${_RSL_STUB_DIR}:${PATH}" STUB_PNPM_EXIT="${2:-0}"     INPUT_SECRETLINT_VERSION="$1" bash "$_RSL_SCRIPT"
}

Describe 'T-RSL-RUN: run-secretlint.sh'
  BeforeEach '_rsl_stub_setup'
  AfterEach '_rsl_stub_cleanup'

  Describe 'command build'
    It '[Normal] T-RSL-RUN-01: runs pnpm dlx secretlint@version with no other arguments'
      When call _rsl_run "14.0.0"
      The status should be success
      The output should equal $'ARG:dlx
ARG:secretlint@14.0.0'
    End
  End

  Describe 'exit code propagation'
    Parameters
      "T-RSL-RUN-03" 1 "findings"
      "T-RSL-RUN-04" 2 "tool error"
    End

    It "[Error] $1: propagates exit $2 ($3) unchanged"
      When call _rsl_run "14.0.0" "$2"
      The status should equal "$2"
      The output should include "ARG:secretlint@14.0.0"
    End
  End

  Describe 'invalid inputs fail before pnpm runs'
    It '[Error] T-RSL-RUN-05: fails with an ::error:: annotation and no pnpm call'
      When call _rsl_run "latest"
      The status should be failure
      The stderr should include "::error::"
      The output should equal ""
    End
  End

  Describe 'no config file'
    It '[Function] T-RSL-RUN-09: passes no config-file option to secretlint'
      When call _rsl_run "14.0.0"
      The status should be success
      The output should not include "--secretlintrc"
      The output should not include "ARG:-c"
      The output should not include "--secretlintignore"
    End
  End
End
