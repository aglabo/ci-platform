#!/usr/bin/env bash
# shellcheck shell=sh
# src: ./.github/actions/validate-environment/scripts/__tests__/validate-apps/functional/get-app-version.functional.spec.sh
# @(#) : Functional tests for get_app_version() in validate-apps.sh

Describe 'get_app_version()'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  Include "${SCRIPT_DIR}/validate-apps.sh"
  export GITHUB_OUTPUT="/dev/null"

  Context 'with existing command'
    It 'returns success for git'
      When call get_app_version "git"
      The status should be success
      The output should not be blank
    End

    It 'outputs non-empty version string'
      When call get_app_version "git"
      The status should be success
      The output should not be blank
    End
  End

  Context 'with non-existent command'
    It 'returns failure'
      When call get_app_version "nonExistentCmd12345"
      The status should be failure
    End
  End

  Context 'with multi-line output command'
    setup_multiline_cmd() {
      TMPDIR_MULTILINE=$(mktemp -d)
      cat > "${TMPDIR_MULTILINE}/multiline-version" << 'SCRIPT'
#!/bin/sh
echo "line one version 1.2.3"
echo "line two extra info"
echo "line three more data"
SCRIPT
      chmod +x "${TMPDIR_MULTILINE}/multiline-version"
      PATH="${TMPDIR_MULTILINE}:${PATH}"
    }
    teardown_multiline_cmd() {
      rm -rf "$TMPDIR_MULTILINE"
    }
    BeforeEach 'setup_multiline_cmd'
    AfterEach 'teardown_multiline_cmd'

    It 'returns success'
      When call get_app_version "multiline-version"
      The status should be success
      The output should not be blank
    End

    It 'returns only first line'
      When call get_app_version "multiline-version"
      The status should be success
      The lines of output should equal 1
    End

    It 'returns first line content'
      When call get_app_version "multiline-version"
      The status should be success
      The output should include "line one version 1.2.3"
    End
  End
End
