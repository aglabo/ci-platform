#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for get_spec_files() function
# Module: runners
# Target: runners/run-shellspec.sh

Describe 'get_spec_files()'
  # --execdir @specfile → cwd is runners/__tests__/unit/
  # Include paths are relative to that directory
  Include ../../run-shellspec.sh

  # ─── Internal Helpers

  setup_spec_tree() {
    _SPEC_TMPDIR=$(mktemp -d)
    mkdir -p "${_SPEC_TMPDIR}/tests/unit"
    mkdir -p "${_SPEC_TMPDIR}/__tests__/unit"
    mkdir -p "${_SPEC_TMPDIR}/__tests__/functional"
    touch "${_SPEC_TMPDIR}/tests/unit/bar.unit.spec.sh"
    touch "${_SPEC_TMPDIR}/__tests__/unit/foo.unit.spec.sh"
    touch "${_SPEC_TMPDIR}/__tests__/functional/baz.functional.spec.sh"
    SPEC_SEARCH_ROOT="${_SPEC_TMPDIR}"
    export SPEC_SEARCH_ROOT
  }

  teardown_spec_tree() {
    if [[ -d "${_SPEC_TMPDIR:-}" ]]; then
      rm -rf "${_SPEC_TMPDIR}"
    fi
    unset _SPEC_TMPDIR SPEC_SEARCH_ROOT
  }

  BeforeEach 'setup_spec_tree'
  AfterEach 'teardown_spec_tree'

  # ─── T-01-01: unit キーワードで __tests__/unit/ がマッチする

  Describe 'Given: SPEC_SEARCH_ROOT に __tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: get_spec_files "unit" を呼ぶ'
      Describe 'Then: T-01-01 - __tests__/unit/ のファイルがリストに含まれる'
        # T-01-01-01
        It 'includes foo.unit.spec.sh from __tests__/unit/'
          When call get_spec_files "unit"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-02: unit キーワードで tests/unit/ もマッチする (既存動作維持)

  Describe 'Given: SPEC_SEARCH_ROOT に tests/unit/bar.unit.spec.sh が存在'
    Describe 'When: get_spec_files "unit" を呼ぶ'
      Describe 'Then: T-01-02 - tests/unit/ のファイルがリストに含まれる'
        # T-01-02-01
        It 'includes bar.unit.spec.sh from tests/unit/'
          When call get_spec_files "unit"
          The output should include "bar.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-03: all キーワードで両ディレクトリが全件返る

  Describe 'Given: tests/unit/ と __tests__/functional/ の両方にファイルが存在'
    Describe 'When: get_spec_files "all" を呼ぶ'
      Describe 'Then: T-01-03 - 両ファイルがリストに含まれる'
        # T-01-03-01a
        It 'includes bar.unit.spec.sh from tests/unit/'
          When call get_spec_files "all"
          The output should include "bar.unit.spec.sh"
          The status should equal 0
        End

        # T-01-03-01b
        It 'includes baz.functional.spec.sh from __tests__/functional/'
          When call get_spec_files "all"
          The output should include "baz.functional.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-04: functional キーワードで __tests__/functional/ がマッチする

  Describe 'Given: SPEC_SEARCH_ROOT に __tests__/functional/baz.functional.spec.sh が存在'
    Describe 'When: get_spec_files "functional" を呼ぶ'
      Describe 'Then: T-01-04 - __tests__/functional/ のファイルがリストに含まれる'
        # T-01-04-01
        It 'includes baz.functional.spec.sh from __tests__/functional/'
          When call get_spec_files "functional"
          The output should include "baz.functional.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-05: 存在しないキーワードで空リストを返す

  Describe 'Given: マッチするファイルがない'
    Describe 'When: get_spec_files "unknown" を呼ぶ'
      Describe 'Then: T-01-05 - 空リストで終了コード 0'
        # T-01-05-01
        It 'returns empty output and exits with 0'
          When call get_spec_files "unknown"
          The output should equal ""
          The status should equal 0
        End
      End
    End
  End

End
