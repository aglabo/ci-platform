#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# cspell:words rhysd invalidrepo

# Test suite for validation.lib.sh functions
# Module: common libs
# Target: _libs/validation.lib.sh
# Functions: validate_symbol, validate_repo, validate_version

Describe 'validate_symbol()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  Context '正常系: 有効なシンボルを受け入れる'
    It 'T-vld-nor-01: returns 0 for valid tool-name "actionlint" matching ^[a-z][a-z0-9_-]*$'
      When call validate_symbol 'actionlint' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 0
    End

    It 'T-vld-nor-02: returns 0 for valid repo "rhysd/actionlint" matching ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
      When call validate_symbol 'rhysd/actionlint' 'repo' '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
      The status should equal 0
    End

    It 'T-vld-nor-03: returns 0 for "actionlint" matching ^[a-z][a-z0-9_-]{0,63}$'
      When call validate_symbol 'actionlint' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$'
      The status should equal 0
    End

    It 'T-vld-nor-04: returns 0 for "my-tool_v2" matching ^[a-z][a-z0-9_-]{0,63}$'
      When call validate_symbol 'my-tool_v2' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$'
      The status should equal 0
    End
  End

  Context '異常系: 無効なシンボルを拒否する'
    It 'T-vld-err-01: returns 1 and stderr with ::error:: for "invalid value!" against ^[a-z]+$'
      When call validate_symbol 'invalid value!' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-err-02: returns 1 and stderr with ::error:: for empty string against ^[a-z]+$'
      When call validate_symbol '' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-err-03: includes field_name "my-field" in stderr message'
      When call validate_symbol 'INVALID' 'my-field' '^[a-z]+$'
      The status should equal 1
      The stderr should include 'my-field'
    End

    It 'T-vld-err-04: includes rejected value "INVALID" in stderr message'
      When call validate_symbol 'INVALID' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include 'INVALID'
    End
  End

  Context 'エッジケース: パターン境界'
    It 'T-vld-edg-01: returns 1 for uppercase "ActionLint" against ^[a-z][a-z0-9_-]*$'
      When call validate_symbol 'ActionLint' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-edg-02: returns 1 for digit-leading "1tool" against ^[a-z][a-z0-9_-]*$'
      When call validate_symbol '1tool' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-edg-03: returns 1 for "abc!" against [a-z]+ (auto-anchored to ^[a-z]+$)'
      When call validate_symbol 'abc!' 'tool-name' '[a-z]+'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-edg-04: returns 0 for 64-char value matching ^[a-z][a-z0-9_-]{0,63}$ with max_length=0'
      When call validate_symbol 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$' 0
      The status should equal 0
    End

    It 'T-vld-edg-05: returns 1 for 65-char value against ^[a-z][a-z0-9_-]{0,63}$ with max_length=0'
      When call validate_symbol 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$' 0
      The status should equal 1
      The stderr should include '::error::'
    End
  End

  Context 'アンカー自動付与'
    It 'T-vld-edg-10: returns 0 for "abc" against [a-z]+ (auto-anchored to ^[a-z]+$)'
      When call validate_symbol 'abc' 'field' '[a-z]+'
      The status should equal 0
    End

    It 'T-vld-edg-11: returns 0 for "abc" against ^[a-z]+ (auto-append $)'
      When call validate_symbol 'abc' 'field' '^[a-z]+'
      The status should equal 0
    End

    It 'T-vld-edg-12: returns 1 for "abc!" against ^[a-z]+ (auto-append $ causes mismatch)'
      When call validate_symbol 'abc!' 'field' '^[a-z]+'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-edg-13: returns 0 for "abc" against ^[a-z]+$ (no double-anchor)'
      When call validate_symbol 'abc' 'field' '^[a-z]+$'
      The status should equal 0
    End
  End

  Context 'max_length: 長さ検証'
    It 'T-vld-edg-06: returns 0 for 10-char value with max_length=10'
      When call validate_symbol 'abcdefghij' 'field' '^[a-z]+$' 10
      The status should equal 0
    End

    It 'T-vld-edg-07: returns 1 for 11-char value with max_length=10'
      When call validate_symbol 'abcdefghijk' 'field' '^[a-z]+$' 10
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-vld-edg-08: returns 0 for long value when max_length=0 (no length limit)'
      When call validate_symbol 'abcdefghijk' 'field' '^[a-z]+$' 0
      The status should equal 0
    End

    It 'T-vld-edg-09: returns 1 for empty string with max_length=10'
      When call validate_symbol '' 'field' '^[a-z]+$' 10
      The status should equal 1
      The stderr should include '::error::'
    End
  End
End

Describe 'validate_repo()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  Context '正常系: 有効なリポジトリを受け入れる'
    It 'T-rep-nor-01: returns 0 for "rhysd/actionlint"'
      When call validate_repo 'rhysd/actionlint'
      The status should equal 0
    End

    It 'T-rep-nor-02: returns 0 for "Microsoft/vscode" (mixed-case owner)'
      When call validate_repo 'Microsoft/vscode'
      The status should equal 0
    End

    It 'T-rep-nor-03: returns 0 for "my-org/repo_name.test" (hyphen/underscore/dot)'
      When call validate_repo 'my-org/repo_name.test'
      The status should equal 0
    End

    It 'T-rep-nor-04: returns 0 for "A/b" (shortest valid value)'
      When call validate_repo 'A/b'
      The status should equal 0
    End
  End

  Context '異常系: 無効なリポジトリを拒否する'
    It 'T-rep-err-01: returns 1 for "invalidrepo" (no slash)'
      When call validate_repo 'invalidrepo'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-err-02: returns 1 for "owner/repo/extra" (two slashes)'
      When call validate_repo 'owner/repo/extra'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-err-03: returns 1 for "../evil/path" (path traversal)'
      When call validate_repo '../evil/path'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-err-04: returns 1 for "-owner/repo" (hyphen-leading owner)'
      When call validate_repo '-owner/repo'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-err-05: returns 1 for "own_er/repo" (underscore in owner)'
      When call validate_repo 'own_er/repo'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-err-06: returns 1 for "" (empty), stderr includes ::error::'
      When call validate_repo ''
      The status should equal 1
      The stderr should include '::error::'
    End
  End

  Context 'エッジケース: 長さ境界と特殊パターン'
    It 'T-rep-edg-01: returns 0 for owner=39chars/b (max owner boundary)'
      When call validate_repo 'Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/b'
      The status should equal 0
    End

    It 'T-rep-edg-02: returns 1 for owner=40chars/b (owner too long)'
      When call validate_repo 'Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/b'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-edg-03: returns 0 for a/repo=100chars (max repo boundary)'
      When call validate_repo 'a/rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'
      The status should equal 0
    End

    It 'T-rep-edg-04: returns 1 for a/repo=101chars (repo too long)'
      When call validate_repo 'a/rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-edg-05: returns 1 for "1owner/repo" (digit-leading owner)'
      When call validate_repo '1owner/repo'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-rep-edg-06: returns 1 for "bad" with no field_name, stderr includes "repo:"'
      When call validate_repo 'bad'
      The status should equal 1
      The stderr should include 'repo:'
    End
  End
End

Describe 'validate_version()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  Context '正常系: 有効なバージョンを受け入れる'
    It 'T-ver-nor-01: returns 0 for "1.2.3" (basic X.Y.Z)'
      When call validate_version '1.2.3'
      The status should equal 0
      The stderr should equal ''
    End

    It 'T-ver-nor-02: returns 0 for "v1.2.3" (lowercase v prefix)'
      When call validate_version 'v1.2.3'
      The status should equal 0
      The stderr should equal ''
    End

    It 'T-ver-nor-03: returns 0 for "V1.2.3" (uppercase V prefix)'
      When call validate_version 'V1.2.3'
      The status should equal 0
      The stderr should equal ''
    End

    It 'T-ver-nor-04: returns 0 for "1.7" (X.Y format without patch)'
      When call validate_version '1.7'
      The status should equal 0
      The stderr should equal ''
    End

    It 'T-ver-nor-05: returns 0 for "v1.7" (v-prefixed X.Y format)'
      When call validate_version 'v1.7'
      The status should equal 0
      The stderr should equal ''
    End
  End

  Context '異常系: 無効なバージョンを拒否する'
    It 'T-ver-err-01: returns 1 for "latest" (non-numeric string), stderr includes ::error::'
      When call validate_version 'latest'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-err-02: returns 1 for "" (empty), stderr includes ::error::'
      When call validate_version ''
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-err-03: returns 1 for "1.2.3-beta" (pre-release suffix), stderr includes ::error::'
      When call validate_version '1.2.3-beta'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-err-04: returns 1 for "1" (major-only), stderr includes ::error::'
      When call validate_version '1'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-err-05: returns 1 for "vv1.2.3" (double v prefix), stderr includes ::error::'
      When call validate_version 'vv1.2.3'
      The status should equal 1
      The stderr should include '::error::'
    End
  End

  Context 'エッジケース: 境界値と特殊パターン'
    It 'T-ver-edg-01: returns 1 for "1.2.3.4" (four-part version), stderr includes ::error::'
      When call validate_version '1.2.3.4'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-edg-02: returns 1 for "1.2." (trailing dot), stderr includes ::error::'
      When call validate_version '1.2.'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-edg-03: returns 0 for "0.0.0" (all-zero version)'
      When call validate_version '0.0.0'
      The status should equal 0
      The stderr should equal ''
    End

    It 'T-ver-edg-04: returns 1 for "v" (prefix only, no numbers), stderr includes ::error::'
      When call validate_version 'v'
      The status should equal 1
      The stderr should include '::error::'
    End

    It 'T-ver-edg-05: returns 1 for "bad" (no field_name), stderr includes "version:"'
      When call validate_version 'bad'
      The status should equal 1
      The stderr should include 'version:'
    End
  End
End
