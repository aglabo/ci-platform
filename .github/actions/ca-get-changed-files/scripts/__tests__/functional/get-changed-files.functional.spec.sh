#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/__tests__/functional/get-changed-files.functional.spec.sh
# @(#) : get-changed-files.sh 機能テスト
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# ─── Internal Helpers ───────────────────────────────────────────────────────

_SCRIPT_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/get-changed-files.sh"
_NORMAL_BEFORE="abc1234567890abcdef1234567890abcdef123456"
_NORMAL_AFTER="def1234567890abcdef1234567890abcdef123456"
_ZERO_SHA="0000000000000000000000000000000000000000"

_stub_dir=""
_output_file=""

setup_env() {
  _stub_dir=$(mktemp -d)
  _output_file=$(mktemp)
  export GITHUB_OUTPUT="$_output_file"
  export PATH="$_stub_dir:$PATH"
}

cleanup_env() {
  rm -rf "$_stub_dir"
  rm -f "$_output_file"
}

make_git_stub() {
  local _stub_output="$1"
  cat > "$_stub_dir/git" << STUB
#!/usr/bin/env bash
echo "${_stub_output}"
STUB
  chmod +x "$_stub_dir/git"
}

run_script() {
  bash "$_SCRIPT_PATH"
}

# ─── Tests ──────────────────────────────────────────────────────────────────

Describe 'get-changed-files.sh'
  BeforeEach 'setup_env'
  AfterEach 'cleanup_env'

  Describe 'When: 通常のSHAと変更ファイルがある'
    Describe 'Then: filesとcountをGITHUB_OUTPUTに書き出す'
      It "T-gcf-nor-01: 正常SHA + ファイルあり → files/count出力"
        make_git_stub "src/main.ts"
        export BEFORE_SHA="$_NORMAL_BEFORE"
        export AFTER_SHA="$_NORMAL_AFTER"
        export PATTERN=""
        When call run_script
        The contents of file "$_output_file" should include "files<<EOF"
        The status should equal 0
      End
    End
  End

  Describe 'When: patternが指定されている'
    Describe 'Then: フィルターされたファイルのみ出力する'
      It "T-gcf-nor-02: PATTERN=*.ts → git diffにpathspecが渡され出力される"
        make_git_stub "src/main.ts"
        export BEFORE_SHA="$_NORMAL_BEFORE"
        export AFTER_SHA="$_NORMAL_AFTER"
        export PATTERN="*.ts"
        When call run_script
        The contents of file "$_output_file" should include "src/main.ts"
        The status should equal 0
      End
    End
  End

  Describe 'When: patternが空（デフォルト）'
    Describe 'Then: 全ファイルを出力する'
      It "T-gcf-nor-03: PATTERN空 + 2ファイル → count=2"
        make_git_stub "$(printf 'src/a.ts\nsrc/b.ts')"
        export BEFORE_SHA="$_NORMAL_BEFORE"
        export AFTER_SHA="$_NORMAL_AFTER"
        export PATTERN=""
        When call run_script
        The contents of file "$_output_file" should include "count=2"
        The status should equal 0
      End
    End
  End

  Describe 'When: BEFORE_SHAがゼロSHA（新ブランチpush）'
    Describe 'Then: empty-treeと差分を取り正常動作する'
      It "T-gcf-edg-01: ゼロSHA → empty-treeでdiff実行、status=0"
        make_git_stub "src/new-file.ts"
        export BEFORE_SHA="$_ZERO_SHA"
        export AFTER_SHA="$_NORMAL_AFTER"
        export PATTERN=""
        When call run_script
        The contents of file "$_output_file" should include "files<<EOF"
        The status should equal 0
      End
    End
  End

  Describe 'When: BEFORE_SHAが未設定'
    Describe 'Then: エラー終了する'
      It "T-gcf-err-01: BEFORE_SHA未設定 → status=1"
        make_git_stub ""
        unset BEFORE_SHA
        export AFTER_SHA="$_NORMAL_AFTER"
        export PATTERN=""
        When call run_script
        The error should include "BEFORE_SHA is required"
        The status should equal 1
      End
    End
  End
End
