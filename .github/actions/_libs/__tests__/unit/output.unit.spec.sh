#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

Describe 'output.lib.sh'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/output.lib.sh"
  Include "$LIB_PATH"

  Describe 'out_status()'
    Context 'GITHUB_OUTPUT 設定済みの場合'
      setup() { export GITHUB_OUTPUT="/tmp/test_output_$$"; }
      cleanup() { rm -f "$GITHUB_OUTPUT"; unset GITHUB_OUTPUT; }
      Before 'setup'
      After 'cleanup'

      It 'GITHUB_OUTPUT のパスを stdout に返す'
        When call out_status
        The output should equal "$GITHUB_OUTPUT"
      End
    End

    Context 'GITHUB_OUTPUT 未設定の場合'
      setup() { unset GITHUB_OUTPUT; }
      Before 'setup'

      It '/dev/null を返す'
        When call out_status
        The output should equal '/dev/null'
      End
    End
  End

  Describe 'write_status()'
    Context 'GITHUB_OUTPUT 設定済みの場合'
      setup() {
        export GITHUB_OUTPUT
        GITHUB_OUTPUT="$(mktemp)"
      }
      cleanup() { rm -f "$GITHUB_OUTPUT"; unset GITHUB_OUTPUT; }
      Before 'setup'
      After 'cleanup'

      It 'ファイルに "status=success" が書き込まれる'
        When call write_status 'success' 'ok'
        The contents of file "$GITHUB_OUTPUT" should include 'status=success'
      End

      It 'ファイルに "message=ok" が書き込まれる'
        When call write_status 'success' 'ok'
        The contents of file "$GITHUB_OUTPUT" should include 'message=ok'
      End

      It '"error" ステータスが正しく書き込まれる'
        When call write_status 'error' 'something failed'
        The contents of file "$GITHUB_OUTPUT" should include 'status=error'
      End

      It 'message にスペースを含む値が書き込まれる'
        When call write_status 'error' 'Git version too old'
        The contents of file "$GITHUB_OUTPUT" should include 'message=Git version too old'
      End

      It 'message が空文字のとき "message=" が書き込まれる'
        When call write_status 'success' ''
        The contents of file "$GITHUB_OUTPUT" should include 'message='
      End

      It '追記モードで複数回呼び出しても既存内容を保持する'
        When call write_status 'success' 'first'
        The status should equal 0
      End
    End

    Context 'GITHUB_OUTPUT 未設定の場合'
      setup() { unset GITHUB_OUTPUT; }
      Before 'setup'

      It 'exit 0 で成功する'
        When call write_status 'success' 'test'
        The status should equal 0
      End
    End
  End
End
