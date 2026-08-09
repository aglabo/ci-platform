#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for get_filelist() function
# Module: runners
# Target: runners/libs/get-filelist.lib.sh

Describe 'get_filelist()'
  # --execdir @specfile → cwd is runners/__tests__/unit/
  Include ../../libs/get-filelist.lib.sh

  # ─── Internal Helpers

  setup_tree() {
    _FL_TMPDIR=$(mktemp -d)
    mkdir -p "${_FL_TMPDIR}/.github/actions/_libs/__tests__/unit"
    touch "${_FL_TMPDIR}/.github/actions/_libs/__tests__/unit/foo.unit.spec.sh"
    mkdir -p "${_FL_TMPDIR}/other/__tests__/unit"
    touch "${_FL_TMPDIR}/other/__tests__/unit/bar.unit.spec.sh"
  }

  teardown_tree() {
    if [[ -d "${_FL_TMPDIR:-}" ]]; then
      rm -rf "${_FL_TMPDIR}"
    fi
    unset _FL_TMPDIR
  }

  BeforeEach 'setup_tree'
  AfterEach 'teardown_tree'

  # ─── T-01-01: ./ なしのパスフィルタで一致する

  Describe 'Given: .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: get_filelist root "*.spec.sh" ".github/actions/_libs" を呼ぶ'
      Describe 'Then: T-01-01 - foo.unit.spec.sh が出力に含まれ bar は含まれない'
        It 'includes foo.unit.spec.sh with path filter (no leading ./)'
          When call get_filelist "$_FL_TMPDIR" "*.spec.sh" ".github/actions/_libs"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End

        It 'excludes bar.unit.spec.sh with path filter (no leading ./)'
          When call get_filelist "$_FL_TMPDIR" "*.spec.sh" ".github/actions/_libs"
          The output should not include "bar.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-02: ./ あり（leading ./）のパスフィルタでも一致する

  Describe 'Given: .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: get_filelist root "*.spec.sh" "./.github/actions/_libs" (leading ./) を呼ぶ'
      Describe 'Then: T-01-02 - foo.unit.spec.sh が出力に含まれ bar は含まれない'
        It 'includes foo.unit.spec.sh with path filter (with leading ./)'
          When call get_filelist "$_FL_TMPDIR" "*.spec.sh" "./.github/actions/_libs"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End

        It 'excludes bar.unit.spec.sh with path filter (with leading ./)'
          When call get_filelist "$_FL_TMPDIR" "*.spec.sh" "./.github/actions/_libs"
          The output should not include "bar.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

End
