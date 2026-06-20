#!/usr/bin/env bash
# src: .github/actions/ca-setup-repo/scripts/__tests__/unit/validate-inputs.unit.spec.sh
# @(#) : ShellSpec unit tests for validate-inputs.lib.sh
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-setup-repo/scripts/_libs/validate-inputs.lib.sh"

# ─── Tests

Describe 'Given: valid inputs are provided'
  Describe 'When: validate_inputs is called with owner/repo, ./tools/agla, v1.0.0'
    Describe 'Then: Task T-01-01 - valid inputs are accepted'
      It "T-01-01-01: exits 0"
        When call validate_inputs "owner/repo" "./tools/agla" "v1.0.0"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: repo has no slash (invalid format)'
  Describe 'When: validate_inputs is called with an invalid repo'
    Describe 'Then: Task T-01-02 - invalid repo is rejected'
      It "T-01-02-01: repo without slash → stderr ::error:: and exits 1"
        When run validate_inputs "agla-doc-tools" "./tools/agla" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End

      It "T-01-02-02: repo with multiple slashes → stderr ::error:: and exits 1"
        When run validate_inputs "owner/repo/extra" "./tools/agla" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: path does not start with "./"'
  Describe 'When: validate_inputs is called with an invalid path prefix'
    Describe 'Then: Task T-01-03 - invalid path is rejected'
      It "T-01-03-01: relative path without ./ → stderr ::error:: and exits 1"
        When run validate_inputs "owner/repo" "tools/agla" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End

      It "T-01-03-03: absolute path → stderr ::error:: and exits 1"
        When run validate_inputs "owner/repo" "/tmp/tools" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: path contains ".." segment'
  Describe 'When: validate_inputs is called with path="./foo/../bar"'
    Describe 'Then: Task T-01-03 - path traversal is rejected'
      It "T-01-03-02: path with .. traversal → stderr ::error:: and exits 1"
        When run validate_inputs "owner/repo" "./foo/../bar" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: ref is empty string'
  Describe 'When: validate_inputs is called with ref=""'
    Describe 'Then: Task T-01-04 - empty ref is rejected'
      It "T-01-04-01: stderr contains ::error:: and exits 1"
        When run validate_inputs "owner/repo" "./tools/agla" ""
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: path contains ".." within a segment (not a traversal)'
  Describe 'When: validate_inputs is called with path="./foo..bar"'
    Describe 'Then: Task T-01-05 - segment-internal ".." is accepted'
      It "T-01-05-01: exits 0 (no path traversal)"
        When call validate_inputs "owner/repo" "./foo..bar" "v1.0.0"
        The status should equal 0
      End
    End
  End
End

Describe 'Given: path="../outside" (starts with .. not ./)'
  Describe 'When: validate_inputs is called with path="../outside"'
    Describe 'Then: Task T-01-05 - path not starting with ./ is rejected'
      It "T-01-05-02: path='../outside' は exit 1 になる"
        When run validate_inputs "owner/repo" "../outside" "v1.0.0"
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End

Describe 'Given: ref is whitespace-only string'
  Describe 'When: validate_inputs is called with ref="  "'
    Describe 'Then: Task T-01-04 - whitespace-only ref is rejected'
      It "T-01-04-02: stderr contains ::error:: and exits 1"
        When run validate_inputs "owner/repo" "./tools/agla" "  "
        The stderr should include "::error::"
        The status should equal 1
      End
    End
  End
End
