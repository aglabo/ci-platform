#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for resolve_spec_files() function
# Module: runners
# Target: runners/run-shellspec.sh

Describe 'resolve_spec_files()'
  # --execdir @specfile → cwd is runners/__tests__/unit/
  # Include paths are relative to that directory
  Include ../../run-shellspec.sh

  # ─── Internal Helpers

  setup_spec_tree() {
    _SPEC_TMPDIR=$(mktemp -d)
    mkdir -p "${_SPEC_TMPDIR}/.github/actions/_libs/__tests__/unit"
    touch "${_SPEC_TMPDIR}/.github/actions/_libs/__tests__/unit/foo.unit.spec.sh"
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

  # ─── T-01-01: Unix スタイルのディレクトリパスでスペックファイルを解決できる

  Describe 'Given: SPEC_SEARCH_ROOT に .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: resolve_spec_files "unit" ".github/actions/_libs" を呼ぶ'
      Describe 'Then: T-01-01 - foo.unit.spec.sh が出力に含まれる'
        # T-01-01-01
        It 'includes foo.unit.spec.sh from .github/actions/_libs/__tests__/unit/'
          When call resolve_spec_files "unit" ".github/actions/_libs"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-02: Windows バックスラッシュパスでスペックファイルを解決できる

  Describe 'Given: SPEC_SEARCH_ROOT に .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: resolve_spec_files "unit" ".github\actions\_libs" (backslash) を呼ぶ'
      Describe 'Then: T-01-02 - foo.unit.spec.sh が出力に含まれる'
        # T-01-02-01
        It 'includes foo.unit.spec.sh when dir arg uses Windows backslashes'
          When call resolve_spec_files "unit" ".github\actions\_libs"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-03: 引数なし（ディレクトリ指定なし）でスペックファイルを解決できる

  Describe 'Given: SPEC_SEARCH_ROOT に .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: resolve_spec_files "unit" を呼ぶ'
      Describe 'Then: T-01-03 - foo.unit.spec.sh が出力に含まれる'
        # T-01-03-01
        It 'includes foo.unit.spec.sh with no directory filter'
          When call resolve_spec_files "unit"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

  # ─── T-01-04: 先頭 ./ 付きディレクトリパスでスペックファイルを解決できる

  Describe 'Given: SPEC_SEARCH_ROOT に .github/actions/_libs/__tests__/unit/foo.unit.spec.sh が存在'
    Describe 'When: resolve_spec_files "unit" "./.github/actions/_libs" (leading ./) を呼ぶ'
      Describe 'Then: T-01-04 - foo.unit.spec.sh が出力に含まれる'
        # T-01-04-01
        It 'includes foo.unit.spec.sh when dir arg has leading ./'
          When call resolve_spec_files "unit" "./.github/actions/_libs"
          The output should include "foo.unit.spec.sh"
          The status should equal 0
        End
      End
    End
  End

End
