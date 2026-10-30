#!/usr/bin/env bash
# src: .github/actions/_libs/__tests__/unit/write-multiline-output.unit.spec.sh
# @(#) : unit tests for write_multiline_output in output.lib.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for write_multiline_output in output.lib.sh
# Module: composite-action/filter-files (test_scope FF, target WMO)
# Target: _libs/output.lib.sh
# Function: write_multiline_output <file> <key> [<line>...]

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/output.lib.sh"

# --- 内部ヘルパー ---
# 関数

##
# Create a per-example temp dir and an empty output file inside it.
# Sets: _wmo_tmpdir (temp dir), _wmo_file (empty file in _wmo_tmpdir)
# @return 0 on success
_wmo_setup() {
  _wmo_tmpdir=$(mktemp -d)
  _wmo_file="${_wmo_tmpdir}/output.txt"
  : >"$_wmo_file"
}

##
# Remove the per-example temp dir created by _wmo_setup.
# Requires: _wmo_tmpdir set by _wmo_setup
# @return 0 always
_wmo_teardown() {
  rm -rf "$_wmo_tmpdir"
}

# --- テスト本体 ---

##
# output.lib.sh: shared GITHUB_OUTPUT helpers for composite actions.
# Assigned test IDs: T-FF-WMO-01 .. T-FF-WMO-25
Describe 'output.lib.sh'
  ##
  # write_multiline_output: append a "<key><<<delimiter>" block to <file>.
  # Scenarios: each <line> argument is written as one line between the header line and
  #            the delimiter line, appending to existing content, with no stdout/stderr output;
  #            with no <line> arguments only the header and delimiter lines are written;
  #            keys containing "-" or starting with "_" are accepted;
  #            an empty <file>, a malformed <key>, or any <line> (not only the first) containing CR or LF
  #            returns 1 and writes nothing (all <line> arguments are checked before any write);
  #            a write failure (<file> is a directory, or its parent directory is missing) returns 2
  #            with no stdout/stderr output and creates no directory;
  #            the delimiter is the first of EOF, EOF_1, EOF_2, ... that equals no <line> argument exactly;
  #            a <line> containing "<<" is written as-is.
  Describe 'write_multiline_output'
    BeforeEach '_wmo_setup'
    AfterEach '_wmo_teardown'

    # 正常系: a delimited multi-line block is appended to the output file
    Context 'When: 正常系'
      It '[Normal] T-FF-WMO-01: 1 行の値を区切り文字で囲んで書く'
        When call write_multiline_output "$_wmo_file" files "a.sh"
        The status should equal 0
        The lines of contents of file "$_wmo_file" should equal 3
        The entire contents of file "$_wmo_file" should equal "files<<EOF${SHELLSPEC_LF}a.sh${SHELLSPEC_LF}EOF${SHELLSPEC_LF}"
      End

      It '[Normal] T-FF-WMO-02: 複数行の値を 1 行ずつ書く'
        When call write_multiline_output "$_wmo_file" files a.sh b.sh
        The status should equal 0
        The lines of contents of file "$_wmo_file" should equal 4
        The entire contents of file "$_wmo_file" should equal "files<<EOF${SHELLSPEC_LF}a.sh${SHELLSPEC_LF}b.sh${SHELLSPEC_LF}EOF${SHELLSPEC_LF}"
      End

      It '[Normal] T-FF-WMO-03: 既存の内容を残して追記する'
        printf '%s\n' 'existing=1' >"$_wmo_file"
        When call write_multiline_output "$_wmo_file" files "a.sh"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'existing=1'
        The line 2 of contents of file "$_wmo_file" should equal 'files<<EOF'
        The lines of contents of file "$_wmo_file" should equal 4
      End

      It '[Normal] T-FF-WMO-04: 成功時は 0 を返し、何も出力しない'
        When call write_multiline_output "$_wmo_file" files "a.sh"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-WMO-05: - を含むキーを受け付ける'
        When call write_multiline_output "$_wmo_file" my-key "a.sh"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'my-key<<EOF'
      End

      It '[Normal] T-FF-WMO-06: _ で始まるキーを受け付ける'
        When call write_multiline_output "$_wmo_file" _k1 "a.sh"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal '_k1<<EOF'
      End
    End

    # 異常系: invalid arguments are rejected with status 1 before any write;
    #         a write failure (directory path, missing parent directory) returns 2
    Context 'When: 異常系'
      It '[Error] T-FF-WMO-07: 出力先が空'
        When call write_multiline_output "" files "a.sh"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-FF-WMO-08: キーに = を含む'
        When call write_multiline_output "$_wmo_file" "a=b" "a.sh"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Error] T-FF-WMO-09: キーに << を含む'
        When call write_multiline_output "$_wmo_file" "a<<b" "a.sh"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Error] T-FF-WMO-10: キーが数字で始まる'
        When call write_multiline_output "$_wmo_file" 1abc "a.sh"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Error] T-FF-WMO-11: キーが空'
        When call write_multiline_output "$_wmo_file" "" "a.sh"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Error] T-FF-WMO-12: 値に CR を含む'
        When call write_multiline_output "$_wmo_file" files $'a\rb.sh'
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Error] T-FF-WMO-13: 出力先がディレクトリなら 2 を返す'
        When call write_multiline_output "$_wmo_tmpdir" files "a.sh"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-FF-WMO-23: 2 番目の行の引数に CR を含む'
        printf '%s\n' 'existing=1' >"$_wmo_file"
        value=$'b\rc.sh'
        When call write_multiline_output "$_wmo_file" files a.sh "$value"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The entire contents of file "$_wmo_file" should equal "existing=1${SHELLSPEC_LF}"
      End

      It '[Error] T-FF-WMO-24: 2 番目の行の引数に LF を含む'
        printf '%s\n' 'existing=1' >"$_wmo_file"
        value=$'b\nc.sh'
        When call write_multiline_output "$_wmo_file" files a.sh "$value"
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The entire contents of file "$_wmo_file" should equal "existing=1${SHELLSPEC_LF}"
      End

      It '[Error] T-FF-WMO-25: 親ディレクトリが無ければ 2 を返す'
        When call write_multiline_output "${_wmo_tmpdir}/no-such-dir/out" files a.sh
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
        The path "${_wmo_tmpdir}/no-such-dir" should not be exist
      End
    End

    # エッジケース: the delimiter is the first of EOF, EOF_1, EOF_2, ... that equals no line argument;
    #             the shape of the line arguments (none, containing LF, containing "<<")
    Context 'When: エッジケース'
      It '[Edge] T-FF-WMO-14: 行の引数に EOF があれば EOF_1 を使う'
        When call write_multiline_output "$_wmo_file" files EOF a.sh
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF_1'
        The line 4 of contents of file "$_wmo_file" should equal 'EOF_1'
        The lines of contents of file "$_wmo_file" should equal 4
      End

      It '[Edge] T-FF-WMO-15: 行の引数に EOF と EOF_1 があれば EOF_2 を使う'
        When call write_multiline_output "$_wmo_file" files EOF EOF_1
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF_2'
        The line 4 of contents of file "$_wmo_file" should equal 'EOF_2'
      End

      It '[Edge] T-FF-WMO-16: EOF_1 の行だけなら EOF を使う'
        When call write_multiline_output "$_wmo_file" files "EOF_1"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF'
      End

      It '[Edge] T-FF-WMO-17: 行の一部に EOF を含むだけなら EOF を使う'
        When call write_multiline_output "$_wmo_file" files "xEOF"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF'
      End

      It '[Edge] T-FF-WMO-18: 末尾に空白の付いた EOF は衝突にしない'
        When call write_multiline_output "$_wmo_file" files "EOF "
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF'
        The line 2 of contents of file "$_wmo_file" should equal 'EOF '
      End

      It '[Edge] T-FF-WMO-19: 行の引数が無ければ内容の行を書かない'
        When call write_multiline_output "$_wmo_file" files
        The status should equal 0
        The lines of contents of file "$_wmo_file" should equal 2
        The entire contents of file "$_wmo_file" should equal "files<<EOF${SHELLSPEC_LF}EOF${SHELLSPEC_LF}"
      End

      It '[Edge] T-FF-WMO-20: LF を含む引数は 1 を返す'
        When call write_multiline_output "$_wmo_file" files $'a\nb'
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wmo_file" should equal ''
      End

      It '[Edge] T-FF-WMO-21: << を含む行をそのまま書く'
        When call write_multiline_output "$_wmo_file" files "a<<b.sh"
        The status should equal 0
        The line 1 of contents of file "$_wmo_file" should equal 'files<<EOF'
        The line 2 of contents of file "$_wmo_file" should equal 'a<<b.sh'
      End

      It '[Edge] T-FF-WMO-22: 空文字列の引数は空行 1 行として書く'
        When call write_multiline_output "$_wmo_file" files a "" b
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The entire contents of file "$_wmo_file" should equal "files<<EOF${SHELLSPEC_LF}a${SHELLSPEC_LF}${SHELLSPEC_LF}b${SHELLSPEC_LF}EOF${SHELLSPEC_LF}"
      End
    End
  End
End
