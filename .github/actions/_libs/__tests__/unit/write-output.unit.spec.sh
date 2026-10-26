#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for write_output in output.lib.sh
# Module: composite-action/resolve-sha (test_scope RS, target WO)
# Target: _libs/output.lib.sh
# Function: write_output <file> <key> <value>

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/output.lib.sh"

# --- 内部ヘルパー ---
# 関数

##
# Create a per-example temp dir and an empty output file inside it.
# Sets: _wo_tmpdir (temp dir), _wo_file (empty file in _wo_tmpdir)
# @return 0 on success
_wo_setup() {
  _wo_tmpdir=$(mktemp -d)
  _wo_file="${_wo_tmpdir}/output.txt"
  : >"$_wo_file"
}

##
# Remove the per-example temp dir created by _wo_setup.
# Requires: _wo_tmpdir set by _wo_setup
# @return 0 always
_wo_teardown() {
  rm -rf "$_wo_tmpdir"
}

# --- テスト本体 ---

##
# output.lib.sh: shared GITHUB_OUTPUT helpers for composite actions.
# Assigned test IDs: T-RS-WO-01 .. T-RS-WO-07, T-RS-WO-09 (T-RS-WO-08 retired: duplicate of T-RS-WO-06)
Describe 'output.lib.sh'
  ##
  # write_output: append one "<key>=<value>" line to <file>.
  # Scenarios: a key=value line is written to an output file, appending to existing content;
  #            an empty file path or a value containing CR/LF is rejected with status 1;
  #            a write failure (directory path, missing parent directory) returns status 2
  #            without writing anything to stderr;
  #            an empty value is accepted and written as "<key>=".
  Describe 'write_output'
    BeforeEach '_wo_setup'
    AfterEach '_wo_teardown'

    # 正常系: a key=value line is appended to the output file
    Context 'When: 正常系'
      It '[Normal] T-RS-WO-01: 空のファイルに before_sha=abc を 1 行書く'
        When call write_output "$_wo_file" before_sha abc
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wo_file" should equal 'before_sha=abc'
        The entire contents of file "$_wo_file" should equal "before_sha=abc${SHELLSPEC_LF}"
      End

      It '[Normal] T-RS-WO-02: existing=1 を持つファイルに resolution=event を追記する'
        printf '%s\n' 'existing=1' >"$_wo_file"
        When call write_output "$_wo_file" resolution event
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The line 1 of contents of file "$_wo_file" should equal 'existing=1'
        The line 2 of contents of file "$_wo_file" should equal 'resolution=event'
        The lines of contents of file "$_wo_file" should equal 2
        The entire contents of file "$_wo_file" should equal "existing=1${SHELLSPEC_LF}resolution=event${SHELLSPEC_LF}"
      End
    End

    # 異常系: invalid arguments are rejected with status 1 before any write; write failures return status 2
    Context 'When: 異常系'
      It '[Error] T-RS-WO-03: 出力先が空なら終了コード 1'
        When call write_output "" key value
        The status should equal 1
        The stdout should equal ''
        The stderr should be blank
      End

      It '[Error] T-RS-WO-04: 値が LF を含むなら終了コード 1'
        When call write_output "$_wo_file" key $'a\nb'
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wo_file" should equal ''
      End

      It '[Error] T-RS-WO-05: 値が単独の CR を含むなら終了コード 1'
        When call write_output "$_wo_file" key $'a\rb'
        The status should equal 1
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wo_file" should equal ''
      End

      It '[Error] T-RS-WO-06: 出力先がディレクトリなら終了コード 2'
        When call write_output "$_wo_tmpdir" key value
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Error] T-RS-WO-07: 出力先の親ディレクトリが無いなら終了コード 2'
        When call write_output "${_wo_tmpdir}/missing/out.txt" key value
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End
    End

    # エッジケース: an empty value is valid and is written as "<key>="
    Context 'When: エッジケース'
      It '[Edge] T-RS-WO-09: 空の値も key= として書く'
        When call write_output "$_wo_file" key ""
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The contents of file "$_wo_file" should equal 'key='
        The entire contents of file "$_wo_file" should equal "key=${SHELLSPEC_LF}"
        The lines of contents of file "$_wo_file" should equal 1
      End
    End
  End
End
