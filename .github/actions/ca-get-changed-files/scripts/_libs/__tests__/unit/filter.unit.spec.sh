#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/_libs/__tests__/unit/filter.unit.spec.sh
# @(#) : filter.lib.sh ユニットテスト
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

# cspell:words aabbccddee

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

Describe 'resolve_sha_for_event'
  _BEFORE_SHA="abc1234567890abcdef1234567890abcdef123456"
  _AFTER_SHA="def1234567890abcdef1234567890abcdef123456"
  _BASE_SHA="base111aabbccddee000000000000000000000000"
  _HEAD_SHA="head222aabbccddee000000000000000000000000"

  Describe 'When: workflow_dispatch イベントが渡された'
    Describe 'Then: T-rsv-edg-01 - 引数の before/after SHA を2行で出力する'
      It "T-rsv-edg-01: workflow_dispatch, before=abc..., after=def... → 2行出力"
        When call resolve_sha_for_event "$_BEFORE_SHA" "$_AFTER_SHA" "workflow_dispatch"
        The output should equal "$(printf '%s\n%s' "$_BEFORE_SHA" "$_AFTER_SHA")"
        The status should equal 0
      End
    End

    Describe 'Then: T-rsv-edg-02 - 引数なし + 環境変数なしのときエラーを返す'
      It "T-rsv-edg-02: workflow_dispatch, no args, no env → Unsupported event エラー + status 1"
        When call resolve_sha_for_event "" "" "workflow_dispatch"
        The output should equal ""
        The error should include "Unsupported event"
        The status should equal 1
      End
    End
  End

  Describe 'When: push イベントが渡された'
    Describe 'Then: T-rsv-nor-01 - 引数の before/after SHA を2行で出力する'
      It "T-rsv-nor-01: push, before=abc..., after=def... → 2行出力"
        When call resolve_sha_for_event "$_BEFORE_SHA" "$_AFTER_SHA" "push"
        The output should equal "$(printf '%s\n%s' "$_BEFORE_SHA" "$_AFTER_SHA")"
        The status should equal 0
      End
    End

    check_push_shas() {
      GITHUB_BEFORE_SHA="$_BEFORE_SHA" GITHUB_AFTER_SHA="$_AFTER_SHA" \
        resolve_sha_for_event "" "" "push"
    }

    check_push_before_empty() {
      GITHUB_BEFORE_SHA="" GITHUB_AFTER_SHA="$_AFTER_SHA" \
        resolve_sha_for_event "" "" "push"
    }

    check_push_after_empty() {
      GITHUB_BEFORE_SHA="$_BEFORE_SHA" GITHUB_AFTER_SHA="" \
        resolve_sha_for_event "" "" "push"
    }

    Describe 'Then: T-rsv-psh-01 - 環境変数から push SHA を解決する'
      It "T-rsv-psh-01: push, GITHUB_BEFORE/AFTER_SHA 設定済み → 2行出力"
        When call check_push_shas
        The output should equal "$(printf '%s\n%s' "$_BEFORE_SHA" "$_AFTER_SHA")"
        The status should equal 0
      End
    End

    Describe 'Then: T-rsv-psh-02 - GITHUB_BEFORE_SHA が空のときエラーを返す'
      It "T-rsv-psh-02: push, GITHUB_BEFORE_SHA="" → エラーメッセージ + status 1"
        When call check_push_before_empty
        The output should equal ""
        The error should include "push event requires GITHUB_BEFORE_SHA and GITHUB_AFTER_SHA"
        The status should equal 1
      End
    End

    Describe 'Then: T-rsv-psh-03 - GITHUB_AFTER_SHA が空のときエラーを返す'
      It "T-rsv-psh-03: push, GITHUB_AFTER_SHA="" → エラーメッセージ + status 1"
        When call check_push_after_empty
        The output should equal ""
        The error should include "push event requires GITHUB_BEFORE_SHA and GITHUB_AFTER_SHA"
        The status should equal 1
      End
    End
  End

  Describe 'When: pull_request イベントが渡された'
    check_pr_shas() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "" "" "pull_request"
    }

    check_pr_base_empty() {
      GITHUB_BASE_SHA="" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "" "" "pull_request"
    }

    check_pr_head_empty() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="" \
        resolve_sha_for_event "" "" "pull_request"
    }

    Describe 'Then: T-rsv-nor-02 - GITHUB_BASE_SHA / GITHUB_HEAD_SHA を2行で出力する'
      It "T-rsv-nor-02: pull_request, BASE=base111..., HEAD=head222... → 2行出力"
        When call check_pr_shas
        The output should equal "$(printf '%s\n%s' "$_BASE_SHA" "$_HEAD_SHA")"
        The status should equal 0
      End
    End

    Describe 'Then: T-rsv-err-01 - GITHUB_BASE_SHA が空のときエラーを返す'
      It "T-rsv-err-01: pull_request, GITHUB_BASE_SHA="" → エラーメッセージ + status 1"
        When call check_pr_base_empty
        The output should equal ""
        The error should include "pull_request event requires GITHUB_BASE_SHA and GITHUB_HEAD_SHA"
        The status should equal 1
      End
    End

    Describe 'Then: T-rsv-err-02 - GITHUB_HEAD_SHA が空のときエラーを返す'
      It "T-rsv-err-02: pull_request, GITHUB_HEAD_SHA="" → エラーメッセージ + status 1"
        When call check_pr_head_empty
        The output should equal ""
        The error should include "pull_request event requires GITHUB_BASE_SHA and GITHUB_HEAD_SHA"
        The status should equal 1
      End
    End
  End

  Describe 'When: before-sha と after-sha が両方指定された'
    check_explicit_push() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "$_BEFORE_SHA" "$_AFTER_SHA" "push"
    }

    check_explicit_pr() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "$_BEFORE_SHA" "$_AFTER_SHA" "pull_request"
    }

    check_explicit_before_only_pr() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "$_BEFORE_SHA" "" "pull_request"
    }

    check_explicit_after_only_pr() {
      GITHUB_BASE_SHA="$_BASE_SHA" GITHUB_HEAD_SHA="$_HEAD_SHA" \
        resolve_sha_for_event "" "$_AFTER_SHA" "pull_request"
    }

    check_explicit_before_only_push() {
      resolve_sha_for_event "$_BEFORE_SHA" "" "push"
    }

    check_explicit_after_only_push() {
      resolve_sha_for_event "" "$_AFTER_SHA" "push"
    }

    Describe 'Then: T-rsv-sha-01 - push イベントで両方指定 → 指定値を返す'
      It "T-rsv-sha-01: push, before=abc..., after=def... → 指定値を2行出力"
        When call check_explicit_push
        The output should equal "$(printf '%s\n%s' "$_BEFORE_SHA" "$_AFTER_SHA")"
        The status should equal 0
      End
    End

    Describe 'Then: T-rsv-sha-02 - pull_request イベントで両方指定 → 指定値を優先する'
      It "T-rsv-sha-02: pull_request, before=abc..., after=def... → 指定値を優先（GITHUB_BASE/HEAD_SHA を無視）"
        When call check_explicit_pr
        The output should equal "$(printf '%s\n%s' "$_BEFORE_SHA" "$_AFTER_SHA")"
        The status should equal 0
      End
    End

    Describe 'Then: T-rsv-sha-03 - pull_request, before のみ指定 → エラーを返す'
      It "T-rsv-sha-03: pull_request, before=abc..., after=empty → エラーメッセージ + status 1"
        When call check_explicit_before_only_pr
        The output should equal ""
        The error should include "before-sha and after-sha must both be specified or both be empty"
        The status should equal 1
      End
    End

    Describe 'Then: T-rsv-sha-04 - pull_request, after のみ指定 → エラーを返す'
      It "T-rsv-sha-04: pull_request, before=empty, after=def... → エラーメッセージ + status 1"
        When call check_explicit_after_only_pr
        The output should equal ""
        The error should include "before-sha and after-sha must both be specified or both be empty"
        The status should equal 1
      End
    End

    Describe 'Then: T-rsv-sha-05 - push, before のみ指定 → エラーを返す'
      It "T-rsv-sha-05: push, before=abc..., after=empty → エラーメッセージ + status 1"
        When call check_explicit_before_only_push
        The output should equal ""
        The error should include "before-sha and after-sha must both be specified or both be empty"
        The status should equal 1
      End
    End

    Describe 'Then: T-rsv-sha-06 - push, after のみ指定 → エラーを返す'
      It "T-rsv-sha-06: push, before=empty, after=def... → エラーメッセージ + status 1"
        When call check_explicit_after_only_push
        The output should equal ""
        The error should include "before-sha and after-sha must both be specified or both be empty"
        The status should equal 1
      End
    End
  End
End

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
