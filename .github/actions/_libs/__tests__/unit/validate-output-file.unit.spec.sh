#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for validate_output_file in output.lib.sh
# Module: composite-action/filter-files (test_scope FF, target VOF)
# Target: _libs/output.lib.sh
# Function: validate_output_file <file>

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/output.lib.sh"

# --- 内部ヘルパー ---
# 関数

##
# Create a per-example temp dir.
# Sets: _vof_tmpdir (temp dir)
# @return 0 on success
_vof_setup() {
  _vof_tmpdir=$(mktemp -d)
}

##
# Restore write permission and remove the per-example temp dir created by _vof_setup.
# Requires: _vof_tmpdir set by _vof_setup
# @return 0 always
_vof_teardown() {
  chmod -R u+w "$_vof_tmpdir"
  rm -rf "$_vof_tmpdir"
}

# --- テスト本体 ---

##
# output.lib.sh: shared GITHUB_OUTPUT helpers for composite actions.
# Assigned test IDs: T-FF-VOF-01 .. T-FF-VOF-13
Describe 'output.lib.sh'
  ##
  # validate_output_file: check that <file> can be used as an output file.
  # Scenarios: a writable existing regular file is accepted with no stdout/stderr output;
  #            a missing path whose parent directory is writable is accepted
  #            without creating the file;
  #            an empty path is rejected with status 1;
  #            an unwritable destination (a directory, a missing or read-only parent
  #            directory, a read-only file) is rejected with status 2
  #            without creating anything;
  #            a non-regular file (a FIFO) is rejected with status 2 without blocking;
  #            a missing path ending in / and a dangling symbolic link are rejected
  #            with status 2;
  #            an existing regular file path with a trailing / is rejected with status 2
  #            without changing the file;
  #            a symbolic link to a writable regular file is accepted;
  #            a rejected path produces no stdout/stderr output.
  Describe 'validate_output_file'
    BeforeEach '_vof_setup'
    AfterEach '_vof_teardown'

    # 正常系: a writable output destination is accepted
    Context 'When: 正常系'
      It '[Normal] T-FF-VOF-01: 書き込み可能な既存の通常ファイルを受け付ける'
        : >"${_vof_tmpdir}/output.txt"
        When call validate_output_file "${_vof_tmpdir}/output.txt"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-VOF-02: 存在しないパスは、親ディレクトリが書き込めれば受け付ける'
        When call validate_output_file "${_vof_tmpdir}/out"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The path "${_vof_tmpdir}/out" should not be exist
      End
    End

    # 異常系: an unusable output destination is rejected
    Context 'When: 異常系'
      It '[Error] T-FF-VOF-03: 空のパスは 1 を返す'
        When call validate_output_file ""
        The status should equal 1
      End

      It '[Error] T-FF-VOF-04: ディレクトリは 2 を返す'
        When call validate_output_file "${_vof_tmpdir}"
        The status should equal 2
      End

      It '[Error] T-FF-VOF-05: 親ディレクトリが無ければ 2 を返す'
        When call validate_output_file "${_vof_tmpdir}/no-such-dir/out"
        The status should equal 2
        The path "${_vof_tmpdir}/no-such-dir" should not be exist
      End

      It '[Error] T-FF-VOF-06: 書き込み権限の無い既存ファイルは 2 を返す'
        Skip if "running as root" [ "$(id -u)" -eq 0 ]
        : >"${_vof_tmpdir}/readonly.txt"
        chmod 444 "${_vof_tmpdir}/readonly.txt"
        When call validate_output_file "${_vof_tmpdir}/readonly.txt"
        The status should equal 2
      End

      It '[Error] T-FF-VOF-07: 親ディレクトリが書き込めなければ 2 を返す'
        Skip if "running as root" [ "$(id -u)" -eq 0 ]
        mkdir "${_vof_tmpdir}/ro-dir"
        chmod 555 "${_vof_tmpdir}/ro-dir"
        When call validate_output_file "${_vof_tmpdir}/ro-dir/out"
        The status should equal 2
      End
    End

    # エッジケース: non-regular files and the absence of output
    Context 'When: エッジケース'
      It '[Edge] T-FF-VOF-08: FIFO は 2 を返す'
        mkfifo "${_vof_tmpdir}/fifo"
        When call validate_output_file "${_vof_tmpdir}/fifo"
        The status should equal 2
        The path "${_vof_tmpdir}/fifo" should be pipe
      End

      It '[Edge] T-FF-VOF-09: 失敗しても何も出力しない'
        When call validate_output_file "${_vof_tmpdir}"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-VOF-10: 存在しない、末尾が / のパスは 2 を返す'
        When call validate_output_file "${_vof_tmpdir}/missing/"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
        The path "${_vof_tmpdir}/missing" should not be exist
      End

      It '[Edge] T-FF-VOF-11: リンク先の無いシンボリックリンクは 2 を返す'
        MSYS=winsymlinks:nativestrict ln -s "${_vof_tmpdir}/no-such-target" "${_vof_tmpdir}/link"
        When call validate_output_file "${_vof_tmpdir}/link"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
        The path "${_vof_tmpdir}/link" should be symlink
        The path "${_vof_tmpdir}/no-such-target" should not be exist
      End

      It '[Edge] T-FF-VOF-12: 既存の通常ファイルの末尾に / を付けたパスは 2 を返す'
        printf 'keep\n' >"${_vof_tmpdir}/out"
        When call validate_output_file "${_vof_tmpdir}/out/"
        The status should equal 2
        The stdout should equal ''
        The stderr should equal ''
        The path "${_vof_tmpdir}/out" should be file
        The contents of file "${_vof_tmpdir}/out" should equal 'keep'
      End

      It '[Edge] T-FF-VOF-13: 書き込める通常ファイルを指すシンボリックリンクは受け付ける'
        : >"${_vof_tmpdir}/real"
        MSYS=winsymlinks:nativestrict ln -s "${_vof_tmpdir}/real" "${_vof_tmpdir}/link"
        When call validate_output_file "${_vof_tmpdir}/link"
        The status should equal 0
        The stdout should equal ''
        The stderr should equal ''
        The path "${_vof_tmpdir}/link" should be symlink
      End
    End
  End
End
