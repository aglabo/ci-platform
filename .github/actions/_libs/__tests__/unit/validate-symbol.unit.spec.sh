#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# cspell:words rhysd

# Test suite for validate_symbol() function
# Module: common libs
# Target: _libs/validation.lib.sh

Describe 'validate_symbol()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/validation.lib.sh"
  Include "$LIB_PATH"

  Context '正常系: 有効なシンボルを受け入れる'
    # T-02-01-01: 有効なツール名
    It 'returns 0 for valid tool-name "actionlint" matching ^[a-z][a-z0-9_-]*$'
      When call validate_symbol 'actionlint' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 0
    End

    # T-02-01-02: 有効なリポジトリ名
    It 'returns 0 for valid repo "rhysd/actionlint" matching ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
      When call validate_symbol 'rhysd/actionlint' 'repo' '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
      The status should equal 0
    End

    # T-02-01-03: 長さ制限付きパターン (setup-tool 由来)
    It 'returns 0 for "actionlint" matching ^[a-z][a-z0-9_-]{0,63}$'
      When call validate_symbol 'actionlint' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$'
      The status should equal 0
    End

    # T-02-01-04: 数字・ハイフン・アンダースコアを含む値 (setup-tool 由来)
    It 'returns 0 for "my-tool_v2" matching ^[a-z][a-z0-9_-]{0,63}$'
      When call validate_symbol 'my-tool_v2' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$'
      The status should equal 0
    End
  End

  Context '異常系: 無効なシンボルを拒否する'
    # T-02-02-01: 不正な文字を含む値
    It 'returns 1 and stderr with ::error:: for "invalid value!" against ^[a-z]+$'
      When call validate_symbol 'invalid value!' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-02-02: 空文字列
    It 'returns 1 and stderr with ::error:: for empty string against ^[a-z]+$'
      When call validate_symbol '' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-02-03: stderr に field_name が含まれる
    It 'includes field_name "my-field" in stderr message'
      When call validate_symbol 'INVALID' 'my-field' '^[a-z]+$'
      The status should equal 1
      The stderr should include 'my-field'
    End

    # T-02-02-04: stderr に value が含まれる
    It 'includes rejected value "INVALID" in stderr message'
      When call validate_symbol 'INVALID' 'tool-name' '^[a-z]+$'
      The status should equal 1
      The stderr should include 'INVALID'
    End
  End

  Context 'エッジケース: パターン境界'
    # T-02-03-01: 大文字を含む値はデフォルトパターンで拒否される
    It 'returns 1 for uppercase "ActionLint" against ^[a-z][a-z0-9_-]*$'
      When call validate_symbol 'ActionLint' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-03-02: 数字始まりは拒否される
    It 'returns 1 for digit-leading "1tool" against ^[a-z][a-z0-9_-]*$'
      When call validate_symbol '1tool' 'tool-name' '^[a-z][a-z0-9_-]*$'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-03-03: アンカー自動付与で完全一致になるため部分一致は拒否される
    It 'returns 1 for "abc!" against [a-z]+ (auto-anchored to ^[a-z]+$)'
      When call validate_symbol 'abc!' 'tool-name' '[a-z]+'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-03-04: 長さ境界 — 64文字（先頭1 + 残63）はパターン一致で通る（max_length=0 で長さチェック無効）
    It 'returns 0 for 64-char value matching ^[a-z][a-z0-9_-]{0,63}$ with max_length=0'
      When call validate_symbol 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$' 0
      The status should equal 0
    End

    # T-02-03-05: 長さ境界 — 65文字はパターン不一致で拒否される（max_length=0 で長さチェック無効）
    It 'returns 1 for 65-char value against ^[a-z][a-z0-9_-]{0,63}$ with max_length=0'
      When call validate_symbol 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'tool-name' '^[a-z][a-z0-9_-]{0,63}$' 0
      The status should equal 1
      The stderr should include '::error::'
    End
  End

  Context 'アンカー自動付与'
    # T-02-05-01: アンカーなし → 両端自動付与で完全一致
    It 'returns 0 for "abc" against [a-z]+ (auto-anchored to ^[a-z]+$)'
      When call validate_symbol 'abc' 'field' '[a-z]+'
      The status should equal 0
    End

    # T-02-05-02: ^ のみあり → $ を自動付与
    It 'returns 0 for "abc" against ^[a-z]+ (auto-append $)'
      When call validate_symbol 'abc' 'field' '^[a-z]+'
      The status should equal 0
    End

    # T-02-05-03: ^ のみあり → $ 付与後に末尾不一致で拒否
    It 'returns 1 for "abc!" against ^[a-z]+ (auto-append $ causes mismatch)'
      When call validate_symbol 'abc!' 'field' '^[a-z]+'
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-05-04: 両端あり → そのまま（二重付与なし）
    It 'returns 0 for "abc" against ^[a-z]+$ (no double-anchor)'
      When call validate_symbol 'abc' 'field' '^[a-z]+$'
      The status should equal 0
    End
  End

  Context 'max_length: 長さ検証'
    # T-02-04-01: max_length=10、10文字値 → 通る
    It 'returns 0 for 10-char value with max_length=10'
      When call validate_symbol 'abcdefghij' 'field' '^[a-z]+$' 10
      The status should equal 0
    End

    # T-02-04-02: max_length=10、11文字値 → 拒否
    It 'returns 1 for 11-char value with max_length=10'
      When call validate_symbol 'abcdefghijk' 'field' '^[a-z]+$' 10
      The status should equal 1
      The stderr should include '::error::'
    End

    # T-02-04-03: max_length=0（省略）→ 長さ制限なし（後方互換）
    It 'returns 0 for long value when max_length=0 (no length limit)'
      When call validate_symbol 'abcdefghijk' 'field' '^[a-z]+$' 0
      The status should equal 0
    End

    # T-02-04-04: max_length=10、空文字 → 拒否
    It 'returns 1 for empty string with max_length=10'
      When call validate_symbol '' 'field' '^[a-z]+$' 10
      The status should equal 1
      The stderr should include '::error::'
    End
  End
End
