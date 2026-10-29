#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Functional test suite for filter-files.sh
# Module: composite-action/filter-files (test_scope FF)
# Target: _ca-filter-files/scripts/filter-files.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# Script under test; executed with bash (not Included) by _mainf_run
_MAINF_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/scripts/filter-files.sh"

# --- 内部ヘルパー ---
# 定数
# 3000 file lines f1.sh .. f3000.sh, each ending with LF; used by
# T-FF-MAINF-33, and the base of _MAINF_FILES_3000
printf -v _MAINF_FILES_3000_LF 'f%d.sh\n' {1..3000}
# The same 3000 lines without the trailing LF; used by T-FF-MAINF-16
_MAINF_FILES_3000="${_MAINF_FILES_3000_LF%$'\n'}"
# 3001 file lines f1.sh .. f3001.sh; used by T-FF-MAINF-21
printf -v _MAINF_FILES_3001 'f%d.sh\n' {1..3001}
# 1000 pattern lines: *.sh (matches every file at once, so the run stays fast)
# followed by p2.md .. p1000.md; used by T-FF-MAINF-16
printf -v _MAINF_PATTERNS_1000 'p%d.md\n' {2..1000}
_MAINF_PATTERNS_1000="*.sh"$'\n'"${_MAINF_PATTERNS_1000%$'\n'}"
# 1001 pattern lines p1.sh .. p1001.sh; used by T-FF-MAINF-22
printf -v _MAINF_PATTERNS_1001 'p%d.sh\n' {1..1001}
# 119997 "a" characters; the base of _MAINF_TEXT_120000 and _MAINF_CR_120001
printf -v _MAINF_A_119997 '%*s' 119997 ''
_MAINF_A_119997="${_MAINF_A_119997// /a}"
# One file line of exactly 120000 bytes; used by T-FF-MAINF-17, and the base
# of _MAINF_TEXT_120001
_MAINF_TEXT_120000="${_MAINF_A_119997}.sh"
# One line of 120001 bytes; used by T-FF-MAINF-23 (files) / T-FF-MAINF-24
# (patterns)
_MAINF_TEXT_120001="a${_MAINF_TEXT_120000}"
# 120001 bytes whose first line has a CR not followed by LF
# (7 bytes "a<CR>b.sh<LF>" + 119994 "a"); used by T-FF-MAINF-31
_MAINF_CR_120001=$'a\rb.sh\n'"${_MAINF_A_119997:3}"
# Line already in the output file before the script runs; used by T-FF-MAINF-35
_MAINF_EXISTING_LINE='existing=1'
# Whole output file when no line is kept; used by T-FF-MAINF-11 / 15 / 28
_MAINF_NO_KEPT_OUTPUT=$'files<<EOF\nEOF\ncount=0'

# 関数

##
# Prepare the per-example environment: a temporary directory holding an empty
# step output file and an empty directory, and the action inputs every case
# shares. INPUT_FILES is unset, so a value from a host CI runner never leaks
# into the script.
# Used by every case (BeforeEach).
# Sets: _MAINF_TMPDIR — the temporary directory;
#       _MAINF_OUTPUT — the output file path (empty);
#       _MAINF_DIR — an empty directory under _MAINF_TMPDIR.
# Exports: GITHUB_OUTPUT="$_MAINF_OUTPUT", INPUT_PATTERNS="".
# ShellSpec skips every AfterEach when a BeforeEach fails, so a step that fails
# after mktemp removes the temporary directory here.
# @return 0 on success, 1 when any step fails
_mainf_setup() {
  _MAINF_TMPDIR=$(mktemp -d) || return 1
  _MAINF_OUTPUT="${_MAINF_TMPDIR}/github_output"
  _MAINF_DIR="${_MAINF_TMPDIR}/outdir"
  if ! : >"$_MAINF_OUTPUT" || ! mkdir "$_MAINF_DIR"; then
    rm -rf "$_MAINF_TMPDIR"
    return 1
  fi
  export GITHUB_OUTPUT="$_MAINF_OUTPUT"
  export INPUT_PATTERNS=""
  unset INPUT_FILES
}

##
# Remove the temporary directory _mainf_setup created (nothing when it is empty).
# Used by every case (AfterEach).
# @return rm's exit code (0 when there is nothing to remove)
_mainf_teardown() {
  [ -z "${_MAINF_TMPDIR:-}" ] && return 0
  rm -rf "$_MAINF_TMPDIR"
}

##
# Run filter-files.sh with bash; the variables a case exported / unset reach
# the script as they are.
# Used by every case.
# @stdout / @stderr the script's output
# @return the script's exit code
_mainf_run() {
  bash "$_MAINF_SCRIPT"
}

##
# Print the value of the multiline files output in the output file: the lines
# after "files<<<delimiter>" up to (not including) the line equal to the
# delimiter. Lines are read with IFS= and read -r, so spaces at both ends and
# backslashes are kept.
# Used by T-FF-MAINF-01 / 02 / 03 / 04 / 05 / 06 / 07 / 08 / 09 / 10 / 12 / 13 /
# 14 / 34.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout the files lines separated by LF, with no trailing LF
# @return 0 when a files<< line is found, 1 otherwise
_mainf_files_output() {
  local _mainf_line _mainf_delim="" _mainf_found=0 _mainf_out="" _mainf_sep=""
  while IFS= read -r _mainf_line; do
    if [ "$_mainf_found" -eq 0 ]; then
      if [[ $_mainf_line == 'files<<'* ]]; then
        _mainf_delim="${_mainf_line#files<<}"
        _mainf_found=1
      fi
      continue
    fi
    [ "$_mainf_line" = "$_mainf_delim" ] && break
    _mainf_out+="${_mainf_sep}${_mainf_line}"
    _mainf_sep=$'\n'
  done <"$_MAINF_OUTPUT"
  [ "$_mainf_found" -eq 1 ] || return 1
  printf '%s' "$_mainf_out"
}

##
# Print the value of the count output (the "count=" line) in the output file.
# Used by T-FF-MAINF-01 / 04 / 12 / 33 / 34.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout the count value
# @return 0 when a count= line is found, 1 otherwise
_mainf_count_output() {
  local _mainf_line
  while IFS= read -r _mainf_line; do
    if [[ $_mainf_line == 'count='* ]]; then
      printf '%s' "${_mainf_line#count=}"
      return 0
    fi
  done <"$_MAINF_OUTPUT"
  return 1
}

##
# Print the delimiter of the multiline files output: the part after "files<<"
# on the first files<< line of the output file.
# Used by T-FF-MAINF-10.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout the delimiter
# @return 0 when a files<< line is found, 1 otherwise
_mainf_delimiter() {
  local _mainf_line
  while IFS= read -r _mainf_line; do
    if [[ $_mainf_line == 'files<<'* ]]; then
      printf '%s' "${_mainf_line#files<<}"
      return 0
    fi
  done <"$_MAINF_OUTPUT"
  return 1
}

##
# Print the number of entries (dot files included) in the directory
# _mainf_setup created.
# Used by T-FF-MAINF-25.
# Requires: _mainf_setup has been called (BeforeEach).
# @stdout the number of entries in _MAINF_DIR
# @return 0
_mainf_dir_entries() {
  (
    shopt -s nullglob dotglob
    local -a _mainf_entries=("$_MAINF_DIR"/*)
    printf '%s' "${#_mainf_entries[@]}"
  )
}

# --- テスト本体 ---

##
# filter-files.sh: entry point of the _ca-filter-files composite action; reads
# the files / patterns inputs from the environment and writes the kept files
# and their count to GITHUB_OUTPUT.
# Assigned test IDs: T-FF-MAINF-01 .. T-FF-MAINF-35
Describe 'filter-files.sh'
  BeforeEach '_mainf_setup'
  AfterEach '_mainf_teardown'

  ##
  # main: check_byte_limit -> check_line_endings -> parse_filelist /
  # parse_patterns -> check_line_limit -> classify_patterns -> filter_files ->
  # emit_outputs, in this order, with the values read from the environment.
  # Scenarios:
  #   normal (the kept files and their count are written):
  #     only the files that match an include pattern are kept; an exclude
  #     pattern wins over an include pattern; with exclude patterns only, every
  #     file not excluded is kept; with no pattern, every file is kept; a * does
  #     not match a /; a ** matches any depth; a ? matches one character; a .
  #     matches only a literal dot; a path that does not exist is matched as a
  #     string; a path equal to the delimiter does not break the output; when
  #     no file matches, an empty files output and a count of 0 are written;
  #     files lines are kept as they are (only blank lines are dropped) while
  #     patterns are trimmed at both ends and blank pattern lines are ignored;
  #     CRLF line endings are turned into LF before the lines are split; a
  #     pattern with no quotes (as YAML leaves it after removing them) is
  #     matched as it is; quotes inside a pattern line are kept as characters;
  #     exactly 3000 files lines and 1000 patterns lines (the line limits) are
  #     accepted; a files input of exactly 120000 bytes (the size limit) is
  #     accepted.
  #   error (one ::error:: line, nothing written to the output file):
  #     an unset GITHUB_OUTPUT; a CR not followed by LF in the files input; a
  #     files line containing a double quote; 3001 files lines (one over the
  #     line limit); 1001 patterns lines (one over the line limit); a files
  #     input of 120001 bytes (one over the size limit); a patterns input of
  #     120001 bytes (one over the size limit); a GITHUB_OUTPUT that is a
  #     directory (nothing is created in the directory); a pattern line of only
  #     "!" (an empty exclude pattern).
  #   edge (boundaries of the stage order, the unset inputs and the output):
  #     with an invalid pattern and an unset GITHUB_OUTPUT, only the pattern
  #     error is reported (emit_outputs is the last stage); an unset files input
  #     is treated as empty and ends with 0 files; an invalid pattern is an
  #     error even when the files input has no line; a single files line left in
  #     git's quoted form ("a\nb.sh") is an error; a files input over the size
  #     limit that also has a CR not followed by LF reports only the size error
  #     (check_byte_limit runs before check_line_endings); a files input with a
  #     CR not followed by LF and an invalid pattern reports only the files
  #     error (check_line_endings runs before classify_patterns); 3000 files
  #     lines with a trailing LF are accepted (the trailing LF is not counted as
  #     a line); an unset patterns input is treated as empty and every file is
  #     kept; a line already in the output file is kept (the outputs are
  #     appended).
  Describe 'main'
    # Cases where the kept files and their count are written to the output file
    Context 'When: 正常系'
      It '[Normal] T-FF-MAINF-01: 包含パターンに一致するファイルだけが残る'
        export INPUT_FILES=$'a.sh\nREADME.md\nb.sh'
        export INPUT_PATTERNS='*.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'a.sh\nb.sh'
        The value "$(_mainf_count_output)" should equal 2
      End

      It '[Normal] T-FF-MAINF-02: 除外は包含より優先する'
        export INPUT_FILES=$'src/a.sh\nsrc/gen/b.sh'
        export INPUT_PATTERNS=$'src/**\n!src/gen/**'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'src/a.sh'
      End

      It '[Normal] T-FF-MAINF-03: 除外だけなら残りの全件が残る'
        export INPUT_FILES=$'a.sh\na.md\nb.sh'
        export INPUT_PATTERNS='!*.md'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'a.sh\nb.sh'
      End

      It '[Normal] T-FF-MAINF-04: パターンが空なら全件を残す'
        export INPUT_FILES=$'a.sh\ndir/b.md'
        export INPUT_PATTERNS=""
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'a.sh\ndir/b.md'
        The value "$(_mainf_count_output)" should equal 2
      End

      It '[Normal] T-FF-MAINF-05: * は / に一致しない'
        export INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'
        export INPUT_PATTERNS='*.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'a.sh'
      End

      It '[Normal] T-FF-MAINF-06: ** は任意階層に一致する'
        export INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'
        export INPUT_PATTERNS='dir/**'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'dir/a.sh\ndir/sub/a.sh'
      End

      It '[Normal] T-FF-MAINF-07: ? は 1 文字に一致する'
        export INPUT_FILES=$'a.sh\ndir/a.sh\ndir/sub/a.sh'
        export INPUT_PATTERNS='dir/?.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'dir/a.sh'
      End

      It '[Normal] T-FF-MAINF-08: ドットはリテラルとして照合される'
        export INPUT_FILES=$'a.sh\naXsh'
        export INPUT_PATTERNS='a.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'a.sh'
      End

      It '[Normal] T-FF-MAINF-09: 実在しないパスも文字列として照合される'
        export INPUT_FILES='no/such/file.sh'
        export INPUT_PATTERNS='**/*.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'no/such/file.sh'
      End

      It '[Normal] T-FF-MAINF-10: 区切り文字と同名のパスを含んでも出力が壊れない'
        export INPUT_FILES=$'EOF\na.sh'
        export INPUT_PATTERNS=""
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_delimiter)" should not equal 'EOF'
        The value "$(_mainf_files_output)" should equal $'EOF\na.sh'
      End

      It '[Normal] T-FF-MAINF-11: 一致が無ければ空の結果で正常終了する'
        export INPUT_FILES='a.md'
        export INPUT_PATTERNS='*.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_NO_KEPT_OUTPUT"
      End

      It '[Normal] T-FF-MAINF-12: files の行は変えず、patterns は両端の空白を除いて空行を無視する'
        export INPUT_FILES=$'  a.sh\n\nmy file.sh\nb.md\n'
        export INPUT_PATTERNS=$'  *.sh  \n\t'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'  a.sh\nmy file.sh'
        The value "$(_mainf_count_output)" should equal 2
      End

      It '[Normal] T-FF-MAINF-13: CRLF の改行を LF に変換してから行に分ける'
        export INPUT_FILES=$'a.sh\r\nb.sh\r\nc.md\n'
        export INPUT_PATTERNS=$'*.sh\r\n'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'a.sh\nb.sh'
        The contents of file "$_MAINF_OUTPUT" should not include $'\r'
      End

      It '[Normal] T-FF-MAINF-14: YAML が外したクオートの無いパターンで照合する'
        export INPUT_FILES=$'a.sh\nb.md'
        export INPUT_PATTERNS='*.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal 'a.sh'
      End

      It '[Normal] T-FF-MAINF-15: 行内のクオートは文字として残る'
        export INPUT_FILES=$'a.sh\nb.md'
        export INPUT_PATTERNS='"a.sh"'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_NO_KEPT_OUTPUT"
      End

      It '[Normal] T-FF-MAINF-16: 件数の上限ちょうどは受け付ける'
        export INPUT_FILES="$_MAINF_FILES_3000"
        export INPUT_PATTERNS="$_MAINF_PATTERNS_1000"
        When call _mainf_run
        The status should equal 0
        The output should equal ''
      End

      It '[Normal] T-FF-MAINF-17: サイズの上限ちょうどは受け付ける'
        export INPUT_FILES="$_MAINF_TEXT_120000"
        export INPUT_PATTERNS=""
        When call _mainf_run
        The value "${#_MAINF_TEXT_120000}" should equal 120000
        The status should equal 0
        The output should equal ''
      End
    End

    # Cases where the script fails with one ::error:: line and writes nothing
    Context 'When: 異常系'
      It '[Error] T-FF-MAINF-18: 出力先が未設定'
        unset GITHUB_OUTPUT
        export INPUT_FILES='a.sh'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::GITHUB_OUTPUT:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-19: LF を伴わない CR を含む'
        export INPUT_FILES=$'a\rb.sh\nc.sh'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-20: ダブルクオートを含む files の行'
        export INPUT_FILES=$'a.sh\n"a\\nb.sh"'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-21: files が 3001 行'
        export INPUT_FILES="$_MAINF_FILES_3001"
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files: '
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-22: patterns が 1001 行'
        export INPUT_FILES='a.sh'
        export INPUT_PATTERNS="$_MAINF_PATTERNS_1001"
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::patterns: '
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-23: files が 120001 バイト'
        export INPUT_FILES="$_MAINF_TEXT_120001"
        When call _mainf_run
        The value "${#_MAINF_TEXT_120001}" should equal 120001
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files: exceeds the limit of 120000 bytes'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-24: patterns が 120001 バイト'
        export INPUT_FILES='a.sh'
        export INPUT_PATTERNS="$_MAINF_TEXT_120001"
        When call _mainf_run
        The value "${#_MAINF_TEXT_120001}" should equal 120001
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::patterns: exceeds the limit of 120000 bytes'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Error] T-FF-MAINF-25: 出力先がディレクトリ'
        export GITHUB_OUTPUT="$_MAINF_DIR"
        export INPUT_FILES='a.sh'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::GITHUB_OUTPUT:'
        The file "$_MAINF_OUTPUT" should be empty file
        The value "$(_mainf_dir_entries)" should equal 0
      End

      It '[Error] T-FF-MAINF-26: ! だけのパターン'
        export INPUT_FILES='a.sh'
        export INPUT_PATTERNS='!'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::patterns:'
        The file "$_MAINF_OUTPUT" should be empty file
      End
    End

    # Cases at the boundaries of the stage order, the unset inputs and the
    # output file
    Context 'When: エッジケース'
      It '[Edge] T-FF-MAINF-27: 不正なパターンと使えない出力先では、パターンのエラーを出す'
        unset GITHUB_OUTPUT
        export INPUT_PATTERNS='!'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::patterns:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Edge] T-FF-MAINF-28: files が未指定なら 0 件で正常終了する'
        unset INPUT_FILES
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The contents of file "$_MAINF_OUTPUT" should equal "$_MAINF_NO_KEPT_OUTPUT"
      End

      It '[Edge] T-FF-MAINF-29: files が 0 行でも不正なパターンはエラー'
        export INPUT_FILES=""
        export INPUT_PATTERNS='! a.sh'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::patterns:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Edge] T-FF-MAINF-30: git の引用表記のままの 1 行はエラー'
        export INPUT_FILES='"a\nb.sh"'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Edge] T-FF-MAINF-31: バイト数の超過と CR があればバイト数のエラーだけを出す'
        export INPUT_FILES="$_MAINF_CR_120001"
        When call _mainf_run
        The value "${#_MAINF_CR_120001}" should equal 120001
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files: exceeds the limit of 120000 bytes'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Edge] T-FF-MAINF-32: files の CR と不正なパターンがあれば files のエラーだけを出す'
        export INPUT_FILES=$'a\rb.sh'
        export INPUT_PATTERNS='!'
        When call _mainf_run
        The status should not equal 0
        The output should equal ''
        The lines of stderr should equal 1
        The line 1 of stderr should start with '::error::files:'
        The file "$_MAINF_OUTPUT" should be empty file
      End

      It '[Edge] T-FF-MAINF-33: 3000 行と末尾の改行は受け付ける'
        export INPUT_FILES="$_MAINF_FILES_3000_LF"
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_count_output)" should equal 3000
      End

      It '[Edge] T-FF-MAINF-34: patterns が未指定なら全件が残る'
        export INPUT_FILES=$'a.sh\nb.md'
        unset INPUT_PATTERNS
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The value "$(_mainf_files_output)" should equal $'a.sh\nb.md'
        The value "$(_mainf_count_output)" should equal 2
      End

      It '[Edge] T-FF-MAINF-35: 既存の出力ファイルの内容を残す'
        printf '%s\n' "$_MAINF_EXISTING_LINE" >"$_MAINF_OUTPUT"
        export INPUT_FILES='a.sh'
        When call _mainf_run
        The status should equal 0
        The output should equal ''
        The line 1 of contents of file "$_MAINF_OUTPUT" should equal 'existing=1'
      End
    End
  End
End
