#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/_libs/__tests__/unit/filter.unit.spec.sh
# @(#) : filter.lib.sh ユニットテスト
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/_libs/filter.lib.sh"

# ─── Internal Helpers ───────────────────────────────────────────────────────

_NORMAL_SHA="abc1234567890abcdef1234567890abcdef123456"
_ZERO_SHA="0000000000000000000000000000000000000000"
_EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
_SHORT_ZEROS="0000000"

_output_file=""

setup_output_file() {
  _output_file=$(mktemp)
  export GITHUB_OUTPUT="$_output_file"
}

cleanup_output_file() {
  rm -f "$_output_file"
}

check_single_line_output() {
  write_multiline_output "files" "src/main.ts"
  cat "$GITHUB_OUTPUT"
}

check_multiline_output() {
  write_multiline_output "files" "$(printf 'src/a.ts\nsrc/b.ts')"
  cat "$GITHUB_OUTPUT"
}

check_zero_value_output() {
  write_multiline_output "count" "0"
  cat "$GITHUB_OUTPUT"
}

# ─── Tests ──────────────────────────────────────────────────────────────────

Describe 'resolve_before_sha'
  Describe 'When: 正常なSHAが入力された'
    Describe 'Then: そのまま返す'
      It "T-rsl-nor-01: 40文字の正常SHA → そのまま返す"
        When call resolve_before_sha "$_NORMAL_SHA"
        The output should equal "$_NORMAL_SHA"
        The status should equal 0
      End
    End
  End

  Describe 'When: ゼロSHAが入力された'
    Describe 'Then: empty-tree SHAを返す'
      It "T-rsl-zer-01: 40桁のゼロ → empty-tree SHAを返す"
        When call resolve_before_sha "$_ZERO_SHA"
        The output should equal "$_EMPTY_TREE"
        The status should equal 0
      End
    End
  End

  Describe 'When: エッジケースの入力'
    Describe 'Then: 空文字はempty-tree SHAを返す'
      It "T-rsl-edg-01: 空文字 → empty-tree SHAを返す"
        When call resolve_before_sha ""
        The output should equal "$_EMPTY_TREE"
        The status should equal 0
      End
    End

    Describe 'Then: 短いゼロ列はそのまま返す'
      It "T-rsl-edg-02: 7桁のゼロ → そのまま返す（40桁のみフォールバック）"
        When call resolve_before_sha "$_SHORT_ZEROS"
        The output should equal "$_SHORT_ZEROS"
        The status should equal 0
      End
    End
  End
End

Describe 'write_multiline_output'
  BeforeEach 'setup_output_file'
  AfterEach 'cleanup_output_file'

  Describe 'When: 単一行の値を書き出す'
    Describe 'Then: multiline EOF形式で出力される'
      It "T-wrt-nor-01: key=files, value=src/main.ts → files<<EOF形式"
        When call check_single_line_output
        The output should equal "$(printf 'files<<EOF\nsrc/main.ts\nEOF')"
        The status should equal 0
      End
    End
  End

  Describe 'When: 複数行の値を書き出す'
    Describe 'Then: 全行を含むEOF形式で出力される'
      It "T-wrt-nor-02: 複数行 → 全行含む形式で出力"
        When call check_multiline_output
        The output should equal "$(printf 'files<<EOF\nsrc/a.ts\nsrc/b.ts\nEOF')"
        The status should equal 0
      End
    End
  End

  Describe 'When: 数値の0を書き出す'
    Describe 'Then: count<<EOF形式で出力される'
      It "T-wrt-edg-01: value=0 → count<<EOF\n0\nEOF"
        When call check_zero_value_output
        The output should equal "$(printf 'count<<EOF\n0\nEOF')"
        The status should equal 0
      End
    End
  End
End
