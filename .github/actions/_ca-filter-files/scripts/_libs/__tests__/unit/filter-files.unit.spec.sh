#!/usr/bin/env bash
# src: .github/actions/_ca-filter-files/scripts/_libs/__tests__/unit/filter-files.unit.spec.sh
# @(#) : unit tests for filter-files.lib.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# cspell:words dirx axxb

# Test suite for filter-files.lib.sh
# Module: composite-action/filter-files (test_scope FF)
# Target: _ca-filter-files/scripts/_libs/filter-files.lib.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/scripts/_libs/filter-files.lib.sh"

# --- 内部ヘルパー ---
# 定数
# Path of filter-files.lib.sh, sourced in a fresh bash process;
# used by T-FF-FE-05, T-FF-FE-06, T-FF-FE-08, T-FF-FE-13
_FE_LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/scripts/_libs/filter-files.lib.sh"
# Value with an LF followed by a workflow command; used by T-FF-FE-07
_FE_INJECTED_VALUE=$'x\n::add-mask::secret'
# Value with a CR; used by T-FF-FE-10
_FE_CR_VALUE=$'a\rb'
# Value with an LF; used by T-FF-FE-11
_FE_LF_VALUE=$'a\nb'
# Text with LF-only line breaks; used by T-FF-CLE-01
_CLE_LF_TEXT=$'a.sh\nb.sh'
# Text with CRLF line breaks; used by T-FF-CLE-02
_CLE_CRLF_TEXT=$'a.sh\r\nb.sh\r\n'
# Text whose last line ends with a CR and no LF; used by T-FF-CLE-04
_CLE_TRAILING_CR_TEXT=$'a.sh\r'
# Text with a CR in the middle of a line; used by T-FF-CLE-05
_CLE_INNER_CR_TEXT=$'a\rb.sh'
# Pattern text whose line ends with a CR and no LF; used by T-FF-CLE-06
_CLE_PATTERN_CR_TEXT=$'*.sh\r'
# Text with a CRLF line followed by a line with a CR; used by T-FF-CLE-07
_CLE_CR_AFTER_CRLF_TEXT=$'a.sh\r\nb\rc.sh'
# Text with two lines that each contain a CR; used by T-FF-CLE-08
_CLE_TWO_CR_LINES_TEXT=$'a\rx\nb\ry'
# Text with an extra CR right before a CRLF; used by T-FF-CLE-09
_CLE_EXTRA_CR_TEXT=$'a\r\r\nb'
# Text with two LF-separated lines; used by T-FF-PFL-01 (input and expected),
# T-FF-PFL-02, T-FF-PFL-04 (expected)
_PFL_TWO_LINES_TEXT=$'a.sh\nb.sh'
# Text with CRLF line breaks; used by T-FF-PFL-02
_PFL_CRLF_TEXT=$'a.sh\r\nb.sh\r\n'
# Text whose only line ends with an LF; used by T-FF-PFL-03
_PFL_TRAILING_LF_TEXT=$'a.sh\n'
# Text with a zero-length line between two lines; used by T-FF-PFL-04
_PFL_EMPTY_LINE_TEXT=$'a.sh\n\nb.sh'
# Text with the same path on two lines; used by T-FF-PFL-05 (input and expected)
_PFL_DUPLICATE_TEXT=$'a.sh\na.sh'
# Text whose only line ends with a tab; used by T-FF-PFL-07 (input and expected)
_PFL_TRAILING_TAB_TEXT=$'a.sh\t'
# Text with a valid line followed by a line with an invalid UTF-8 byte;
# used by T-FF-PFL-11
_PFL_BAD_UTF8_TEXT=$'a.sh\n\xff.sh'
# Text with a double-quoted line followed by a line with an invalid UTF-8
# byte; used by T-FF-PFL-14
_PFL_QUOTE_THEN_BAD_UTF8_TEXT=$'"a.sh"\n\xff.sh'
# Text with a line with an invalid UTF-8 byte followed by a double-quoted
# line; used by T-FF-PFL-15
_PFL_BAD_UTF8_THEN_QUOTE_TEXT=$'\xff.sh\n"a.sh"'
# Text with one double-quoted line that also has an invalid UTF-8 byte;
# used by T-FF-PFL-16
_PFL_QUOTED_BAD_UTF8_TEXT=$'"\xff.sh"'
# Line with an overlong 2-byte form of "/" (C0 AF); used by T-FF-PFL-20
_PFL_OVERLONG_2_TEXT=$'\xc0\xaf.sh'
# Line with an overlong 3-byte form of NUL (E0 80 80); used by T-FF-PFL-21
_PFL_OVERLONG_3_TEXT=$'\xe0\x80\x80.sh'
# Line with an overlong 4-byte form of U+FFFF (F0 8F BF BF); used by T-FF-PFL-22
_PFL_OVERLONG_4_TEXT=$'\xf0\x8f\xbf\xbf.sh'
# Line with the surrogate U+D800 (ED A0 80); used by T-FF-PFL-23
_PFL_SURROGATE_TEXT=$'\xed\xa0\x80.sh'
# Line with U+110000, above U+10FFFF (F4 90 80 80); used by T-FF-PFL-24
_PFL_ABOVE_MAX_TEXT=$'\xf4\x90\x80\x80.sh'
# Line with the lead byte F5, never valid in UTF-8 (F5 80 80 80); used by
# T-FF-PFL-25
_PFL_LEAD_F5_TEXT=$'\xf5\x80\x80\x80.sh'
# Line with a 3-byte sequence cut after 2 bytes (E3 81); used by T-FF-PFL-26
_PFL_TRUNCATED_TEXT=$'a\xe3\x81.sh'
# Line with a continuation byte and no lead byte (80); used by T-FF-PFL-27
_PFL_LONE_CONT_TEXT=$'a\x80.sh'
# Line with U+0080, the smallest 2-byte character (C2 80); used by T-FF-PFL-28
_PFL_MIN_2_TEXT=$'\xc2\x80.sh'
# Line with U+FFFF, the largest 3-byte character (EF BF BF); used by T-FF-PFL-29
_PFL_MAX_3_TEXT=$'\xef\xbf\xbf.sh'
# Line with U+10FFFF, the largest code point (F4 8F BF BF); used by T-FF-PFL-30
_PFL_MAX_4_TEXT=$'\xf4\x8f\xbf\xbf.sh'
# Text made only of LFs; used by T-FF-PFL-18
_PFL_NEWLINES_ONLY_TEXT=$'\n\n'
# Pattern text with two LF-separated lines; used by T-FF-PPT-01 (input and expected)
_PPT_TWO_LINES_TEXT=$'*.sh\n!*.md'
# Pattern line followed by a tab; used by T-FF-PPT-03
_PPT_TRAILING_TAB_TEXT=$'*.sh\t'
# Pattern line followed by a line made only of a tab; used by T-FF-PPT-04
_PPT_TAB_ONLY_LINE_TEXT=$'*.sh\n\t'
# Pattern line ending with CRLF; used by T-FF-PPT-05
_PPT_CRLF_TEXT=$'*.sh\r\n'
# Pattern line with an invalid UTF-8 byte; used by T-FF-PPT-08
_PPT_BAD_UTF8_TEXT=$'\xff.sh'
# Valid pattern line followed by a line with an invalid UTF-8 byte; used by T-FF-PPT-12
_PPT_BAD_UTF8_SECOND_LINE_TEXT=$'*.sh\nx\xff'
# Locale set by the caller of check_byte_limit in the UTF-8 cases;
# used by T-FF-CBL-06, T-FF-CBL-07, T-FF-CBL-08
_CBL_UTF8_LOCALE="C.UTF-8"
# ASCII text of exactly 120000 bytes ("a" x 120000); used by T-FF-CBL-02
printf -v _CBL_ASCII_MAX_TEXT 'a%.0s' {1..120000}
# ASCII text of 120001 bytes ("a" x 120001); used by T-FF-CBL-04, T-FF-CBL-05
printf -v _CBL_ASCII_OVER_TEXT 'a%.0s' {1..120001}
# "あ" (3 bytes in UTF-8) x 40001 = 120003 bytes; used by T-FF-CBL-06
printf -v _CBL_KANA_OVER_TEXT 'あ%.0s' {1..40001}
# "あ" x 40000 = 120000 bytes; used by T-FF-CBL-07
printf -v _CBL_KANA_MAX_TEXT 'あ%.0s' {1..40000}
# files lines of exactly FF_MAX_FILES (3000) lines ("a.sh" each, no trailing
# LF); used by T-FF-CLL-02
printf -v _CLL_FILES_MAX_LINES 'a.sh\n%.0s' {1..3000}
_CLL_FILES_MAX_LINES=${_CLL_FILES_MAX_LINES%$'\n'}
# patterns lines of exactly FF_MAX_PATTERNS (100) lines ("*.sh" each, no
# trailing LF); used by T-FF-CLL-03
printf -v _CLL_PATTERNS_MAX_LINES '*.sh\n%.0s' {1..100}
_CLL_PATTERNS_MAX_LINES=${_CLL_PATTERNS_MAX_LINES%$'\n'}
# files lines of FF_MAX_FILES + 1 (3001) lines; used by T-FF-CLL-04
printf -v _CLL_FILES_OVER_LINES 'a.sh\n%.0s' {1..3001}
_CLL_FILES_OVER_LINES=${_CLL_FILES_OVER_LINES%$'\n'}
# patterns lines of FF_MAX_PATTERNS + 1 (101) lines; used by T-FF-CLL-05
printf -v _CLL_PATTERNS_OVER_LINES '*.sh\n%.0s' {1..101}
_CLL_PATTERNS_OVER_LINES=${_CLL_PATTERNS_OVER_LINES%$'\n'}
# Two lines; used by T-FF-CLL-08
_CLL_TWO_LINES=$'a\nb'
# Pattern lines with an include followed by an exclude; used by T-FF-CP-03
_CP_ORDERED_PATTERNS=$'src/**\n!src/gen/**'
# Pattern line wrapped in double quotes; used by T-FF-CP-04
_CP_QUOTED_PATTERN='"b.sh"'
# Exclude pattern line whose rest starts with a tab; used by T-FF-CP-07
_CP_TAB_EXCLUDE_PATTERN=$'!\ta.sh'
# Two rejected pattern lines ("!" then "! a.sh"); used by T-FF-CP-10
_CP_TWO_BAD_LINES=$'!\n! a.sh'
# Include pattern line with a tab inside the pattern; used by T-FF-CP-11
_CP_INNER_TAB_PATTERN=$'a\tb'
# Include pattern line that ends with one backslash; used by T-FF-CP-12
_CP_BACKSLASH_PATTERN="a\\"
# Locale set while matching a path against the converted ERE;
# used by T-FF-GTR-01 .. T-FF-GTR-15, T-FF-GTR-17 .. T-FF-GTR-40
_GTR_UTF8_LOCALE="C.UTF-8"
# Glob that ends with one backslash; used by T-FF-GTR-21, T-FF-GTR-22
_GTR_BACKSLASH_GLOB="a\\"
# Path that ends with one backslash; used by T-FF-GTR-21
_GTR_BACKSLASH_PATH="a\\"
# Glob wrapped in double quotes; used by T-FF-GTR-23
_GTR_QUOTED_GLOB='"b.sh"'
# Path whose first character is a non-ASCII (3-byte UTF-8) character;
# used by T-FF-GTR-37
_GTR_MULTIBYTE_PATH='あ.sh'
# Files with two .sh lines around a README.md line; used by T-FF-FF-01,
# T-FF-FF-10
_FF_SH_MD_FILES=$'a.sh\nREADME.md\nb.sh'
# The two .sh lines of _FF_SH_MD_FILES / _FF_SH_MD_SH_FILES in input order;
# used by T-FF-FF-01, T-FF-FF-03, T-FF-FF-10 (expected)
_FF_SH_FILES=$'a.sh\nb.sh'
# Files under src/, one of them under src/gen/; used by T-FF-FF-02,
# T-FF-FF-15 (input and expected)
_FF_SRC_FILES=$'src/a.sh\nsrc/gen/b.sh'
# Files with an .md line between two .sh lines; used by T-FF-FF-03
_FF_SH_MD_SH_FILES=$'a.sh\na.md\nb.sh'
# Files at the top level and in a directory; used by T-FF-FF-04 (input and
# expected)
_FF_MIXED_DIR_FILES=$'a.sh\ndir/b.md'
# Files not in pattern order (.md, .sh, .md); used by T-FF-FF-05 (input and
# expected)
_FF_UNSORTED_FILES=$'b.md\na.sh\nc.md'
# Two include patterns (.sh first, then .md); used by T-FF-FF-05
_FF_SH_MD_PATTERNS=$'*.sh\n*.md'
# The same path on two lines; used by T-FF-FF-08 (input and expected)
_FF_DUPLICATE_FILES=$'a.sh\na.sh'
# Locale of the caller of filter_files; used by T-FF-FF-13
_FF_C_LOCALE="C"
# Path whose first character is a non-ASCII (3-byte UTF-8) character;
# used by T-FF-FF-13 (input and expected)
_FF_MULTIBYTE_PATH='あ.sh'
# A path that does not exist but matches **/*.sh, then a path that exists
# in the working directory but does not match; used by T-FF-FF-14
_FF_FS_FILES=$'no/such/file.sh\nexists.md'
# Files under src/, two of them under src/gen/; used by T-FF-FF-16
_FF_KEEP_FILES=$'src/a.sh\nsrc/gen/b.sh\nsrc/gen/keep.sh'
# Files at the top level and in docs/ (.sh, .md, docs/.md); used by
# T-FF-FF-17
_FF_DOCS_FILES=$'a.sh\nb.md\ndocs/c.md'
# A path with a TAB inside, then the same characters without it; used by
# T-FF-FF-18
_FF_TAB_FILES=$'a\tb\nab'
# The path with a TAB inside from _FF_TAB_FILES; used by T-FF-FF-18
# (pattern and expected)
_FF_TAB_PATH=$'a\tb'
# Files with an .md line and an .sh line; used by T-FF-FF-19 (input and
# expected)
_FF_MD_SH_FILES=$'a.md\nb.sh'
# A path that starts with "!", then the same path without it; used by
# T-FF-FF-20
_FF_BANG_FILES=$'!a.sh\na.sh'
# Kept lines a.sh and b.sh, LF-separated with no trailing LF; used by T-FF-EO-01
_EO_TWO_KEPT=$'a.sh\nb.sh'
# Whole output file after emitting _EO_TWO_KEPT; used by T-FF-EO-01
_EO_TWO_KEPT_OUTPUT=$'files<<EOF\na.sh\nb.sh\nEOF\ncount=2'
# Whole output file after emitting no kept lines; used by T-FF-EO-04
_EO_NO_KEPT_OUTPUT=$'files<<EOF\nEOF\ncount=0'
# Kept lines whose first line equals the default delimiter EOF; used by T-FF-EO-10
_EO_EOF_KEPT=$'EOF\na.sh'
# 1000 kept lines f1.sh .. f1000.sh, LF-separated with no trailing LF;
# used by T-FF-EO-11
printf -v _EO_THOUSAND_KEPT 'f%d.sh\n' {1..1000}
_EO_THOUSAND_KEPT=${_EO_THOUSAND_KEPT%$'\n'}
# Line already in the output file before emit_outputs runs; used by T-FF-EO-12
_EO_EXISTING_LINE='existing=1'

##
# Source filter-files.lib.sh in a fresh bash process and print the observable
# state; used by the load guard group (T-FF-FE-05, T-FF-FE-13).
# The spec shell has already loaded the library via Include, so the source runs
# in a new process with FILTER_FILES_LIB_LOADED and OUTPUT_LIB_LOADED unset; if
# $1 is given, FILTER_FILES_LIB_LOADED is preset to it.
# @arg $1 preset — optional value assigned to FILTER_FILES_LIB_LOADED before sourcing
# @stdout one per line:
#         "loaded=<FILTER_FILES_LIB_LOADED>",
#         "ff_error=<defined|undefined>",
#         "validate_output_file=<defined|undefined>",
#         "write_multiline_output=<defined|undefined>",
#         "write_output=<defined|undefined>",
#         "source_status=<exit status of the source>"
# @return exit status of the fresh bash process
_fe_source_lib_in_fresh_shell() {
  bash -c '
    unset FILTER_FILES_LIB_LOADED OUTPUT_LIB_LOADED
    [ "$#" -ge 2 ] && FILTER_FILES_LIB_LOADED="$2"
    . "$1"
    _source_status=$?
    echo "loaded=${FILTER_FILES_LIB_LOADED:-}"
    for _fn in ff_error validate_output_file write_multiline_output write_output; do
      if declare -F "$_fn" >/dev/null; then
        echo "${_fn}=defined"
      else
        echo "${_fn}=undefined"
      fi
    done
    echo "source_status=${_source_status}"
  ' _ "$_FE_LIB_PATH" "$@"
}

##
# Source filter-files.lib.sh twice in a fresh bash process; used by the load
# guard group (T-FF-FE-06). FILTER_FILES_LIB_LOADED and OUTPUT_LIB_LOADED are
# unset first, so the first source loads the library and the second one
# sources it again in the already-loaded state.
# @stdout nothing
# @stderr whatever either source writes to stderr
# @return exit status of the second source
_fe_resource_lib_in_fresh_shell() {
  bash -c '
    unset FILTER_FILES_LIB_LOADED OUTPUT_LIB_LOADED
    . "$1"
    . "$1"
  ' _ "$_FE_LIB_PATH"
}

##
# Create a per-example temp dir; used by the load guard group (T-FF-FE-08).
# @set _fe_tmpdir — path of the created temp dir
# @return 0 always
_fe_setup() {
  _fe_tmpdir=$(mktemp -d)
}

##
# Remove the per-example temp dir created by _fe_setup.
# Requires: _fe_tmpdir set by _fe_setup
# @return 0 always
_fe_teardown() {
  rm -rf "$_fe_tmpdir"
}

##
# Copy only filter-files.lib.sh to ${_fe_tmpdir}/action/scripts/_libs/ and
# source the copy in a fresh bash process; used by T-FF-FE-08.
# The copy's relative shared library ${_fe_tmpdir}/_libs/output.lib.sh does
# not exist, so the source cannot load it. FILTER_FILES_LIB_LOADED and
# OUTPUT_LIB_LOADED are unset first.
# Requires: _fe_tmpdir set by _fe_setup
# @stderr whatever the source writes to stderr
# @return exit status of the source
_fe_source_isolated_copy() {
  local _copy_dir="${_fe_tmpdir}/action/scripts/_libs"
  mkdir -p "$_copy_dir"
  cp "$_FE_LIB_PATH" "${_copy_dir}/filter-files.lib.sh"
  bash -c '
    unset FILTER_FILES_LIB_LOADED OUTPUT_LIB_LOADED
    . "$1"
  ' _ "${_copy_dir}/filter-files.lib.sh"
}

##
# Run check_byte_limit with the caller's LC_ALL set to _CBL_UTF8_LOCALE
# (function-local, so it never leaks between examples); used by
# T-FF-CBL-06, T-FF-CBL-07.
# @arg $@ arguments passed to check_byte_limit as is
# @return check_byte_limit's exit code
_cbl_check_in_utf8() {
  local LC_ALL="$_CBL_UTF8_LOCALE"
  check_byte_limit "$@"
}

##
# With the caller's LC_ALL set to _CBL_UTF8_LOCALE (function-local), call
# check_byte_limit files a.sh "$FF_MAX_FILES_BYTES" and print LC_ALL as seen
# by the caller afterwards; used by T-FF-CBL-08.
# @stdout the caller's LC_ALL after the call
# @return check_byte_limit's exit code
_cbl_lc_all_after_check() {
  local LC_ALL="$_CBL_UTF8_LOCALE" _rc=0
  check_byte_limit files a.sh "$FF_MAX_FILES_BYTES" || _rc=$?
  printf '%s' "$LC_ALL"
  return "$_rc"
}

##
# Convert <glob> with glob_to_regex and match <path> against the result as
# an ERE, with LC_ALL set to _GTR_UTF8_LOCALE (function-local, so it never
# leaks between examples); used by T-FF-GTR-01 .. T-FF-GTR-15,
# T-FF-GTR-17 .. T-FF-GTR-40.
# @arg $1 glob — glob passed to glob_to_regex as is
# @arg $2 path — path matched against the converted ERE
# @stdout (none)
# @return 0 when <path> matches, 1 when it does not, 2 when glob_to_regex
#         fails (including when it is not defined)
_gtr_match() {
  local LC_ALL="$_GTR_UTF8_LOCALE" _re
  _re=$(glob_to_regex "$1") || return 2
  [[ $2 =~ $_re ]]
}

##
# Run filter_files with the given shell options enabled in the caller, then
# restore the options; used by T-FF-FF-10, T-FF-FF-11, T-FF-FF-19.
# filter_files is called directly (not in a subshell), so options it
# changed would be seen here.
# @arg $1 files    — passed to filter_files as is
# @arg $2 patterns — passed to filter_files as is (pattern / !pattern lines)
# @arg $3.. names of the shopt options to enable (e.g. nocasematch)
# @stdout filter_files' stdout
# @return filter_files' exit code
_ff_filter_with_options() {
  local _files="$1" _patterns="$2" _saved _rc=0
  shift 2
  _saved=$(shopt -p "$@") || :
  shopt -s "$@"
  filter_files "$_files" "$_patterns" || _rc=$?
  eval "$_saved"
  return "$_rc"
}

##
# With nocasematch enabled in the caller, call filter_files directly (not in
# a subshell) and print whether nocasematch is still enabled afterwards;
# the caller's option is restored before returning; used by T-FF-FF-12.
# @arg $@ arguments passed to filter_files as is
# @stdout filter_files' stdout, then "nocasematch=on" or "nocasematch=off"
# @return filter_files' exit code
_ff_nocasematch_after_call() {
  local _saved _rc=0
  _saved=$(shopt -p nocasematch) || :
  shopt -s nocasematch
  filter_files "$@" || _rc=$?
  if shopt -q nocasematch; then
    printf '%s\n' 'nocasematch=on'
  else
    printf '%s\n' 'nocasematch=off'
  fi
  eval "$_saved"
  return "$_rc"
}

##
# With the caller's LC_ALL set to _FF_C_LOCALE (function-local, so it never
# leaks between examples), call filter_files directly (not in a subshell)
# and print the caller's LC_ALL afterwards; used by T-FF-FF-13.
# @arg $@ arguments passed to filter_files as is
# @stdout filter_files' stdout, then "LC_ALL=<caller's LC_ALL after the call>"
# @return filter_files' exit code
_ff_filter_in_c_locale() {
  local LC_ALL="$_FF_C_LOCALE"
  local _rc=0
  filter_files "$@" || _rc=$?
  printf 'LC_ALL=%s\n' "$LC_ALL"
  return "$_rc"
}

##
# Run filter_files with a fresh temp dir as the working directory; the dir
# is outside any git work tree and holds one empty file, exists.md; used by
# T-FF-FF-14. The temp dir is created and removed here (also when
# filter_files fails); filter_files runs in a subshell so that the spec
# shell's working directory does not change.
# @arg $@ arguments passed to filter_files as is
# @stdout filter_files' stdout
# @return filter_files' exit code; 3 when the temp dir cannot be prepared
#         or is inside a git work tree (the precondition does not hold)
_ff_filter_outside_repo() {
  local _dir _rc=0
  _dir=$(mktemp -d) || return 3
  (
    cd "$_dir" || exit 3
    : >exists.md || exit 3
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      exit 3
    fi
    filter_files "$@"
  ) || _rc=$?
  rm -rf "$_dir"
  return "$_rc"
}

##
# Create a per-example temp dir holding an empty output file and an empty
# sub-directory; used by every emit_outputs example (BeforeEach).
# Sets: _eo_tmpdir (temp dir), _eo_file (empty file ${_eo_tmpdir}/github_output),
#       _eo_dir (empty directory ${_eo_tmpdir}/outdir)
# @return 0 on success, non-zero when the temp dir cannot be prepared
_eo_setup() {
  _eo_tmpdir=$(mktemp -d) || return 1
  _eo_file="${_eo_tmpdir}/github_output"
  _eo_dir="${_eo_tmpdir}/outdir"
  : >"$_eo_file" && mkdir "$_eo_dir"
}

##
# Remove the per-example temp dir created by _eo_setup (AfterEach).
# Requires: _eo_tmpdir set by _eo_setup
# @return 0 always
_eo_teardown() {
  rm -rf "$_eo_tmpdir"
}

##
# Run emit_outputs with all the arguments, then count the entries (including
# dot files) left in <dir>; used by T-FF-EO-06.
# Sets: _eo_dir_entries — number of entries in <dir> after the call
# @arg $1 dir  — directory passed to emit_outputs as the output file
# @arg $2 kept — kept lines passed to emit_outputs as is
# @return emit_outputs's exit code
_eo_run_into_dir() {
  local _rc=0
  emit_outputs "$@" || _rc=$?
  _eo_dir_entries=$(
    shopt -s nullglob dotglob
    set -- "$1"/*
    printf '%s' "$#"
  )
  return "$_rc"
}

##
# Replace write_multiline_output with a stub that returns 2 (a write failure)
# without writing anything, run emit_outputs with all the arguments, then
# restore the original definition; used by T-FF-EO-08.
# @arg $1 file — output file passed to emit_outputs as is
# @arg $2 kept — kept lines passed to emit_outputs as is
# @return emit_outputs's exit code; 3 when write_multiline_output is not
#         defined (the precondition does not hold)
_eo_run_with_failing_wmo() {
  local _saved _rc=0
  _saved=$(declare -f write_multiline_output) || return 3
  # shellcheck disable=SC2329 # invoked indirectly by emit_outputs
  write_multiline_output() { return 2; }
  emit_outputs "$@" || _rc=$?
  eval "$_saved"
  return "$_rc"
}

##
# Replace write_output with a stub that returns 2 (a write failure) without
# writing anything, run emit_outputs with all the arguments, then restore the
# original definition; used by T-FF-EO-09. write_multiline_output is not
# replaced, so the files output is really written first.
# @arg $1 file — output file passed to emit_outputs as is
# @arg $2 kept — kept lines passed to emit_outputs as is
# @return emit_outputs's exit code; 3 when write_output is not defined (the
#         precondition does not hold)
_eo_run_with_failing_wo() {
  local _saved _rc=0
  _saved=$(declare -f write_output) || return 3
  # shellcheck disable=SC2329 # invoked indirectly by emit_outputs
  write_output() { return 2; }
  emit_outputs "$@" || _rc=$?
  eval "$_saved"
  return "$_rc"
}

##
# Write the single line _EO_EXISTING_LINE to <file>, then run emit_outputs
# with all the arguments; used by T-FF-EO-12.
# Requires: _eo_setup has run (the directory of <file> exists)
# @arg $1 file — output file passed to emit_outputs as is
# @arg $2 kept — kept lines passed to emit_outputs as is
# @return emit_outputs's exit code; 3 when <file> cannot be prepared
_eo_run_with_existing() {
  printf '%s\n' "$_EO_EXISTING_LINE" >"$1" || return 3
  emit_outputs "$@"
}

# --- テスト本体 ---

##
# filter-files.lib.sh: helper functions for the _ca-filter-files composite action.
# Assigned test IDs: T-FF-FE-01 .. T-FF-FE-13, T-FF-CLE-01 .. T-FF-CLE-09,
#                    T-FF-PFL-01 .. T-FF-PFL-19, T-FF-PPT-01 .. T-FF-PPT-12,
#                    T-FF-CBL-01 .. T-FF-CBL-08, T-FF-CLL-01 .. T-FF-CLL-08,
#                    T-FF-CP-01 .. T-FF-CP-12, T-FF-GTR-01 .. T-FF-GTR-40,
#                    T-FF-FF-01 .. T-FF-FF-20, T-FF-EO-01 .. T-FF-EO-13
Describe 'filter-files.lib.sh'
  ##
  # ff_error: emit one "::error::" annotation line to stderr. The form is chosen
  # by the argument count:
  #   normal form (value passed):  "::error::<target>: <problem> (got: '<value>')"
  #   empty form  (value omitted): "::error::<target>: value must not be empty"
  # <value> is encoded so that it cannot break the line, "%" first:
  # "%" -> "%25", then CR -> "%0D", then LF -> "%0A".
  # Scenarios: the normal form is written to stderr only (stdout stays empty);
  #            an explicitly passed empty value still uses the normal form;
  #            an omitted value uses the empty form;
  #            a value with LF and a workflow command stays on one line;
  #            "%", CR and LF are each encoded, and an already-encoded-looking
  #            value ("%0A") has its "%" encoded rather than kept.
  Describe 'ff_error'
    # 正常系: FE-01..03 the normal form (value passed), FE-04 the empty form (value omitted)
    Context 'When: 正常系'
      It '[Normal] T-FF-FE-01: 通常の形式で stderr に 1 行出す'
        When call ff_error files "bad line" x
        The status should equal 0
        The stderr should equal "::error::files: bad line (got: 'x')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-FF-FE-02: stdout には何も出さない'
        When call ff_error files "bad line" x
        The status should equal 0
        The stdout should equal ''
        The stderr should be present
      End

      It '[Normal] T-FF-FE-03: 空文字列の値は通常の形式で出す'
        When call ff_error patterns p ""
        The status should equal 0
        The stderr should start with "::error::patterns: p"
        The stderr should end with "(got: '')"
        The lines of stderr should equal 1
      End

      It '[Normal] T-FF-FE-04: 空の形式で出す'
        When call ff_error GITHUB_OUTPUT empty
        The status should equal 0
        The stderr should equal "::error::GITHUB_OUTPUT: value must not be empty"
        The lines of stderr should equal 1
      End
    End

    # 異常系: FE-07 a value with LF and a workflow command stays on one line
    Context 'When: 異常系'
      It '[Error] T-FF-FE-07: LF とコマンドを含む値を 1 行に収める'
        When call ff_error files bad "$_FE_INJECTED_VALUE"
        The status should equal 0
        The lines of stderr should equal 1
        The stderr should not include "${SHELLSPEC_LF}::add-mask::"
        The stderr should include "(got: 'x%0A::add-mask::secret')"
      End
    End

    # エッジケース: FE-09..12 value encoding (% first, then CR, then LF)
    Context 'When: エッジケース'
      It '[Edge] T-FF-FE-09: % を %25 にする'
        When call ff_error t p "a%b"
        The status should equal 0
        The stderr should include "(got: 'a%25b')"
      End

      It '[Edge] T-FF-FE-10: CR を %0D にする'
        When call ff_error t p "$_FE_CR_VALUE"
        The status should equal 0
        The stderr should include "(got: 'a%0Db')"
      End

      It '[Edge] T-FF-FE-11: LF を %0A にする'
        When call ff_error t p "$_FE_LF_VALUE"
        The status should equal 0
        The stderr should include "(got: 'a%0Ab')"
      End

      It '[Edge] T-FF-FE-12: 既にエンコード済みに見える値は % から先に置き換える'
        When call ff_error t p "%0A"
        The status should equal 0
        The stderr should include "(got: '%250A')"
      End
    End
  End

  ##
  # check_line_endings: check one input (files or patterns) for a CR that is
  # not followed by LF, and report only the first offending line via ff_error.
  # Assigned test IDs: T-FF-CLE-01, T-FF-CLE-02, T-FF-CLE-03, T-FF-CLE-04,
  #                    T-FF-CLE-05, T-FF-CLE-06, T-FF-CLE-07, T-FF-CLE-08,
  #                    T-FF-CLE-09
  # Scenarios: LF-only line breaks are accepted (status 0, empty stderr);
  #            CRLF line breaks are accepted (CRLF is not inspected);
  #            an empty string is accepted;
  #            a CR at the end of the last line (no LF after it) is reported
  #            (status 1, one ::error:: line with the line CR-encoded);
  #            a CR in the middle of a line is reported likewise;
  #            the error names the checked input (e.g. patterns);
  #            a CR line after a CRLF line is reported as that line only;
  #            with several CR lines, only the first one is reported;
  #            an extra CR right before a CRLF is reported (status 1).
  Describe 'check_line_endings'
    # 正常系: CLE-01 LF-only line breaks, CLE-02 CRLF line breaks,
    #         CLE-03 empty string
    Context 'When: 正常系'
      It '[Normal] T-FF-CLE-01: LF だけの改行を受け付ける'
        When call check_line_endings files "$_CLE_LF_TEXT"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-CLE-02: CRLF の改行を受け付ける'
        When call check_line_endings files "$_CLE_CRLF_TEXT"
        The status should equal 0
      End

      It '[Normal] T-FF-CLE-03: 空文字列を受け付ける'
        When call check_line_endings files ""
        The status should equal 0
      End
    End

    # 異常系: CLE-04 a CR at the end of the last line (no LF after it),
    #         CLE-05 a CR in the middle of a line,
    #         CLE-06 the error names the target patterns
    Context 'When: 異常系'
      It '[Error] T-FF-CLE-04: 行末の CR をエラーにする'
        When call check_line_endings files "$_CLE_TRAILING_CR_TEXT"
        The status should equal 1
        The stderr should start with "::error::files:"
        The stderr should include "(got: 'a.sh%0D')"
        The lines of stderr should equal 1
      End

      It '[Error] T-FF-CLE-05: 行の途中の CR をエラーにする'
        When call check_line_endings files "$_CLE_INNER_CR_TEXT"
        The status should equal 1
        The stderr should include "(got: 'a%0Db.sh')"
      End

      It '[Error] T-FF-CLE-06: 対象が patterns ならその名前で報告する'
        When call check_line_endings patterns "$_CLE_PATTERN_CR_TEXT"
        The status should equal 1
        The stderr should start with "::error::patterns:"
      End
    End

    # エッジケース: CLE-07 a CR line after a CRLF line is reported alone,
    #             CLE-08 only the first of several CR lines is reported,
    #             CLE-09 an extra CR right before a CRLF is reported
    Context 'When: エッジケース'
      It '[Edge] T-FF-CLE-07: CRLF の行の後にある CR の行を報告する'
        When call check_line_endings files "$_CLE_CR_AFTER_CRLF_TEXT"
        The status should equal 1
        The stderr should include "(got: 'b%0Dc.sh')"
        The stderr should not include "a.sh"
      End

      It '[Edge] T-FF-CLE-08: CR を含む行が複数あっても最初の 1 行だけを報告する'
        When call check_line_endings files "$_CLE_TWO_CR_LINES_TEXT"
        The status should equal 1
        The lines of stderr should equal 1
        The stderr should include "(got: 'a%0Dx')"
      End

      It '[Edge] T-FF-CLE-09: CRLF の直前に余分な CR があればエラーにする'
        When call check_line_endings files "$_CLE_EXTRA_CR_TEXT"
        The status should equal 1
        The stderr should start with "::error::files:"
      End
    End
  End

  ##
  # parse_filelist: split the files input into lines and print them
  # LF-separated (no trailing LF).
  # Assigned test IDs: T-FF-PFL-01, T-FF-PFL-02, T-FF-PFL-03, T-FF-PFL-04,
  #                    T-FF-PFL-05, T-FF-PFL-06, T-FF-PFL-07, T-FF-PFL-08,
  #                    T-FF-PFL-09, T-FF-PFL-10, T-FF-PFL-11, T-FF-PFL-12,
  #                    T-FF-PFL-13, T-FF-PFL-14, T-FF-PFL-15, T-FF-PFL-16,
  #                    T-FF-PFL-17, T-FF-PFL-18, T-FF-PFL-19, T-FF-PFL-20,
  #                    T-FF-PFL-21, T-FF-PFL-22, T-FF-PFL-23, T-FF-PFL-24,
  #                    T-FF-PFL-25, T-FF-PFL-26, T-FF-PFL-27, T-FF-PFL-28,
  #                    T-FF-PFL-29, T-FF-PFL-30
  # Scenarios: two LF-separated lines are returned unchanged; CRLF line
  #            breaks are converted to LF; a trailing LF yields no empty
  #            line; a zero-length line is dropped; duplicate paths are
  #            kept (status 0, no trailing LF, empty stderr);
  #            lines are not changed: leading whitespace and a trailing tab
  #            are kept; a whitespace-only line is kept as one path;
  #            a space in the middle of a line is kept (no word splitting);
  #            a line starting with "!" is kept as a path ("!" has a
  #            meaning only in patterns);
  #            a line that is not valid UTF-8 is reported (status 1, one
  #            ::error::files: line, empty stdout); so are overlong forms,
  #            a surrogate, code points above U+10FFFF, the lead byte F5,
  #            a truncated sequence and a lone continuation byte (RFC 3629);
  #            a line containing a
  #            double quote is reported with its value (status 1); a line
  #            still in git's quoted form ("a\nb.sh", backslash and n) is
  #            reported with the backslash unchanged (status 1);
  #            errors are reported in line order: a double quote on an
  #            earlier line wins over invalid UTF-8 on a later line, and
  #            invalid UTF-8 on an earlier line wins over a double quote on
  #            a later line; on the same line, invalid UTF-8 wins over a
  #            double quote;
  #            an empty string gives 0 lines (status 0, empty stdout and
  #            stderr); an input made only of LFs also gives 0 lines;
  #            a non-ASCII line that is valid UTF-8 is kept unchanged, also
  #            at the boundaries U+0080, U+FFFF and U+10FFFF.
  Describe 'parse_filelist'
    # 正常系: PFL-01 two LF-separated lines, PFL-02 CRLF converted to LF,
    #         PFL-03 no empty line for a trailing LF,
    #         PFL-04 a zero-length line is dropped,
    #         PFL-05 duplicate paths are kept,
    #         PFL-06 leading whitespace is kept,
    #         PFL-07 a trailing tab is kept,
    #         PFL-08 a whitespace-only line is kept,
    #         PFL-09 a space in the middle of a line is kept,
    #         PFL-10 a line starting with "!" is kept as a path
    Context 'When: 正常系'
      It '[Normal] T-FF-PFL-01: LF で区切った 2 行をそのまま返す'
        When call parse_filelist "$_PFL_TWO_LINES_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_TWO_LINES_TEXT"
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-02: CRLF を LF に変換する'
        When call parse_filelist "$_PFL_CRLF_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_TWO_LINES_TEXT"
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-03: 末尾の LF による空行を出さない'
        When call parse_filelist "$_PFL_TRAILING_LF_TEXT"
        The status should equal 0
        The entire output should equal 'a.sh'
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-04: 長さ 0 の行を捨てる'
        When call parse_filelist "$_PFL_EMPTY_LINE_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_TWO_LINES_TEXT"
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-05: 同じパスの重複を残す'
        When call parse_filelist "$_PFL_DUPLICATE_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_DUPLICATE_TEXT"
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-06: 先頭の空白を残す'
        When call parse_filelist '  a.sh'
        The status should equal 0
        The entire output should equal '  a.sh'
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-07: 末尾のタブを残す'
        When call parse_filelist "$_PFL_TRAILING_TAB_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_TRAILING_TAB_TEXT"
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-08: 空白だけの行を 1 行のパスとして残す'
        When call parse_filelist '  '
        The status should equal 0
        The entire output should equal '  '
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-09: 途中の空白を残す'
        When call parse_filelist 'my file.sh'
        The status should equal 0
        The entire output should equal 'my file.sh'
        The stderr should equal ''
      End
      It '[Normal] T-FF-PFL-10: ! で始まる行をパスとして残す'
        When call parse_filelist '!a.sh'
        The status should equal 0
        The entire output should equal '!a.sh'
        The stderr should equal ''
      End
    End

    # 異常系: PFL-11 a line that is not valid UTF-8 is reported
    #         (nothing is printed to stdout, even for the valid line before it),
    #         PFL-12 a line containing a double quote is reported,
    #         PFL-13 a line still in git's quoted form is reported
    #         (the backslash is passed through unchanged),
    #         PFL-14 a double quote on an earlier line is reported before
    #         invalid UTF-8 on a later line (errors are reported in line order),
    #         PFL-15 invalid UTF-8 on an earlier line is reported before
    #         a double quote on a later line,
    #         PFL-16 invalid UTF-8 is reported when the same line also has
    #         a double quote,
    #         PFL-20 .. 22 overlong 2 / 3 / 4-byte forms are reported,
    #         PFL-23 a surrogate is reported,
    #         PFL-24 a code point above U+10FFFF is reported,
    #         PFL-25 the lead byte F5 is reported,
    #         PFL-26 a truncated sequence is reported,
    #         PFL-27 a lone continuation byte is reported
    Context 'When: 異常系'
      It '[Error] T-FF-PFL-11: UTF-8 として不正な行をエラーにする'
        When call parse_filelist "$_PFL_BAD_UTF8_TEXT"
        The status should equal 1
        The stderr should start with "::error::files:"
        The stderr should include "invalid UTF-8"
        The lines of stderr should equal 1
        The output should equal ''
      End
      It '[Error] T-FF-PFL-12: ダブルクオートを含む行をエラーにする'
        When call parse_filelist '"b.sh"'
        The status should equal 1
        The stderr should start with "::error::files:"
        The stderr should include "(got: '\"b.sh\"')"
        The stderr should include "double quote"
      End
      It '[Error] T-FF-PFL-13: git の引用表記のままの行をエラーにする'
        When call parse_filelist '"a\nb.sh"'
        The status should equal 1
        The stderr should start with "::error::files:"
        The stderr should include "(got: '\"a\\nb.sh\"')"
        The stderr should include "double quote"
      End
      It '[Error] T-FF-PFL-14: 前の行のダブルクオートを、後の行の不正な UTF-8 より先に報告する'
        When call parse_filelist "$_PFL_QUOTE_THEN_BAD_UTF8_TEXT"
        The status should equal 1
        The lines of stderr should equal 1
        The stderr should include "(got: '\"a.sh\"')"
        The stderr should include "double quote"
      End
      It '[Error] T-FF-PFL-15: 前の行の不正な UTF-8 を、後の行のダブルクオートより先に報告する'
        When call parse_filelist "$_PFL_BAD_UTF8_THEN_QUOTE_TEXT"
        The status should equal 1
        The lines of stderr should equal 1
        The stderr should not include '"a.sh"'
        The stderr should include "invalid UTF-8"
      End
      It '[Error] T-FF-PFL-16: 同じ行に両方あれば UTF-8 のエラーを報告する'
        When call parse_filelist "$_PFL_QUOTED_BAD_UTF8_TEXT"
        The status should equal 1
        The lines of stderr should equal 1
        The stderr should include "invalid UTF-8"
        The stderr should not include "double quote"
      End
      It '[Error] T-FF-PFL-20: 2 バイトの冗長表現 (C0 AF) をエラーにする'
        When call parse_filelist "$_PFL_OVERLONG_2_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-21: 3 バイトの冗長表現 (E0 80 80) をエラーにする'
        When call parse_filelist "$_PFL_OVERLONG_3_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-22: 4 バイトの冗長表現 (F0 8F BF BF) をエラーにする'
        When call parse_filelist "$_PFL_OVERLONG_4_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-23: サロゲート (ED A0 80) をエラーにする'
        When call parse_filelist "$_PFL_SURROGATE_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-24: U+10FFFF を超える符号位置 (F4 90 80 80) をエラーにする'
        When call parse_filelist "$_PFL_ABOVE_MAX_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-25: 先頭バイト F5 をエラーにする'
        When call parse_filelist "$_PFL_LEAD_F5_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-26: 途中で切れたバイト列 (E3 81) をエラーにする'
        When call parse_filelist "$_PFL_TRUNCATED_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
      It '[Error] T-FF-PFL-27: 先頭バイトの無い継続バイト (80) をエラーにする'
        When call parse_filelist "$_PFL_LONE_CONT_TEXT"
        The status should equal 1
        The stderr should include "invalid UTF-8"
        The output should equal ''
      End
    End

    # エッジケース: PFL-17 an empty string gives 0 lines,
    #             PFL-18 an input made only of LFs gives 0 lines,
    #             PFL-19 a non-ASCII line that is valid UTF-8 is kept,
    #             PFL-28 U+0080 (the smallest 2-byte character) is kept,
    #             PFL-29 U+FFFF (the largest 3-byte character) is kept,
    #             PFL-30 U+10FFFF (the largest code point) is kept
    Context 'When: エッジケース'
      It '[Edge] T-FF-PFL-17: 空文字列は 0 行'
        When call parse_filelist ""
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End
      It '[Edge] T-FF-PFL-18: 改行だけの入力は 0 行'
        When call parse_filelist "$_PFL_NEWLINES_ONLY_TEXT"
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End
      It '[Edge] T-FF-PFL-19: UTF-8 として正しい非 ASCII の行を残す'
        When call parse_filelist 'あ.sh'
        The status should equal 0
        The entire output should equal 'あ.sh'
        The stderr should equal ''
      End
      It '[Edge] T-FF-PFL-28: U+0080 (C2 80) の行を残す'
        When call parse_filelist "$_PFL_MIN_2_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_MIN_2_TEXT"
        The stderr should equal ''
      End
      It '[Edge] T-FF-PFL-29: U+FFFF (EF BF BF) の行を残す'
        When call parse_filelist "$_PFL_MAX_3_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_MAX_3_TEXT"
        The stderr should equal ''
      End
      It '[Edge] T-FF-PFL-30: U+10FFFF (F4 8F BF BF) の行を残す'
        When call parse_filelist "$_PFL_MAX_4_TEXT"
        The status should equal 0
        The entire output should equal "$_PFL_MAX_4_TEXT"
        The stderr should equal ''
      End
    End
  End

  ##
  # parse_patterns: split the patterns input into lines and print them
  # LF-separated (no trailing LF).
  # Assigned test IDs: T-FF-PPT-01, T-FF-PPT-02, T-FF-PPT-03, T-FF-PPT-04,
  #                    T-FF-PPT-05, T-FF-PPT-06, T-FF-PPT-07, T-FF-PPT-08,
  #                    T-FF-PPT-09, T-FF-PPT-10, T-FF-PPT-11, T-FF-PPT-12
  # Scenarios: two LF-separated lines (one starting with "!") are returned
  #            unchanged; spaces at both ends of a line are removed; a
  #            trailing tab is removed; a line made only of whitespace is
  #            dropped after the removal; CRLF line breaks are converted to
  #            LF (no CR is left in the output); a double quote is kept as
  #            an ordinary character; a space in the middle of a line is
  #            kept (only both ends are trimmed)
  #            (status 0, no trailing LF, empty stderr);
  #            a line that is not valid UTF-8 is reported (status 1, one
  #            ::error::patterns: line, empty stdout);
  #            an empty string gives 0 lines (status 0, empty stdout and
  #            stderr); a "!" after leading spaces is trimmed to "!" alone
  #            and accepted (status 0, empty stderr; the error belongs to CP);
  #            spaces after a leading "!" are not removed again (DD-IN-02;
  #            status 0, empty stderr); an invalid UTF-8 byte on the second
  #            line is reported with that line only (status 1, one stderr
  #            line without the first line, empty stdout).
  Describe 'parse_patterns'
    # 正常系: PPT-01 two LF-separated lines, PPT-02 spaces at both ends removed,
    #         PPT-03 trailing tab removed,
    #         PPT-04 a whitespace-only line is dropped,
    #         PPT-05 CRLF converted to LF,
    #         PPT-06 a double quote is kept as a character,
    #         PPT-07 a space in the middle of a line is kept
    Context 'When: 正常系'
      It '[Normal] T-FF-PPT-01: LF で区切った 2 行をそのまま返す'
        When call parse_patterns "$_PPT_TWO_LINES_TEXT"
        The status should equal 0
        The entire output should equal "$_PPT_TWO_LINES_TEXT"
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-02: 両端のスペースを除く'
        When call parse_patterns '  *.sh  '
        The status should equal 0
        The entire output should equal '*.sh'
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-03: 末尾のタブを除く'
        When call parse_patterns "$_PPT_TRAILING_TAB_TEXT"
        The status should equal 0
        The entire output should equal '*.sh'
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-04: 空白だけの行を捨てる'
        When call parse_patterns "$_PPT_TAB_ONLY_LINE_TEXT"
        The status should equal 0
        The entire output should equal '*.sh'
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-05: CRLF を LF に変換する'
        When call parse_patterns "$_PPT_CRLF_TEXT"
        The status should equal 0
        The entire output should equal '*.sh'
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-06: ダブルクオートを文字として残す'
        When call parse_patterns '"b.sh"'
        The status should equal 0
        The entire output should equal '"b.sh"'
        The stderr should equal ''
      End

      It '[Normal] T-FF-PPT-07: 途中の空白を残す'
        When call parse_patterns 'a b.sh'
        The status should equal 0
        The entire output should equal 'a b.sh'
        The stderr should equal ''
      End
    End

    # 異常系: PPT-08 a line that is not valid UTF-8 is reported
    #         (nothing is printed to stdout)
    Context 'When: 異常系'
      It '[Error] T-FF-PPT-08: UTF-8 として不正な行をエラーにする'
        When call parse_patterns "$_PPT_BAD_UTF8_TEXT"
        The status should equal 1
        The stderr should start with "::error::patterns:"
        The stderr should include "invalid UTF-8"
        The lines of stderr should equal 1
        The output should equal ''
      End
    End

    # エッジケース: PPT-09 an empty string gives 0 lines,
    #              PPT-10 a "!" after leading spaces is left as "!" alone
    #              (no error; reporting it is CP's job),
    #              PPT-11 spaces after a leading "!" are kept (DD-IN-02),
    #              PPT-12 an invalid UTF-8 byte on the second line is reported
    #              with that line only (nothing is printed to stdout)
    Context 'When: エッジケース'
      It '[Edge] T-FF-PPT-09: 空文字列は 0 行'
        When call parse_patterns ""
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-PPT-10: 空白で始まる ! は除去後に ! だけになる'
        When call parse_patterns '  !'
        The status should equal 0
        The entire output should equal '!'
        The stderr should equal ''
      End

      It '[Edge] T-FF-PPT-11: ! の後の空白は除去しない'
        When call parse_patterns '!  a.sh'
        The status should equal 0
        The entire output should equal '!  a.sh'
        The stderr should equal ''
      End

      It '[Edge] T-FF-PPT-12: 2 行目の不正な UTF-8 を報告する'
        When call parse_patterns "$_PPT_BAD_UTF8_SECOND_LINE_TEXT"
        The status should equal 1
        The lines of stderr should equal 1
        The stderr should include "invalid UTF-8"
        The stderr should not include '*.sh'
        The output should equal ''
      End
    End
  End

  ##
  # check_byte_limit: check that one input (files or patterns) is within its
  # byte limit, counted in bytes before conversion or splitting.
  # Assigned test IDs: T-FF-CBL-01, T-FF-CBL-02, T-FF-CBL-03, T-FF-CBL-04,
  #                    T-FF-CBL-05, T-FF-CBL-06, T-FF-CBL-07, T-FF-CBL-08
  # Scenarios: the byte-limit constants FF_MAX_FILES_BYTES and
  #            FF_MAX_PATTERNS_BYTES are both 120000 and readonly
  #            (status 0, empty stderr); a files value of exactly
  #            FF_MAX_FILES_BYTES bytes is accepted (status 0, empty stderr);
  #            a small files value (a.sh) is accepted (status 0, empty stderr);
  #            a files value of FF_MAX_FILES_BYTES + 1 bytes is rejected
  #            (status 1, one ::error::files: line with the byte count);
  #            a patterns value of FF_MAX_PATTERNS_BYTES + 1 bytes is
  #            rejected under its own name (status 1, one ::error::patterns:
  #            line); with the caller's LC_ALL set to C.UTF-8, a files value
  #            of 40001 "あ" is counted as 120003 bytes, not 40001 characters,
  #            and rejected (status 1, ::error::files: line with 120003);
  #            with the caller's LC_ALL set to C.UTF-8, a files value of
  #            40000 "あ" (exactly 120000 bytes) is accepted (status 0,
  #            empty stderr); with the caller's LC_ALL set to C.UTF-8, the
  #            caller's LC_ALL is still C.UTF-8 after the check (status 0,
  #            empty stderr).
  Describe 'check_byte_limit'
    # 正常系: CBL-01 the byte-limit constants are 120000 and readonly,
    #         CBL-02 a value of exactly the limit is accepted,
    #         CBL-03 a small value is accepted
    Context 'When: 正常系'
      It '[Normal] T-FF-CBL-01: バイト数の上限の定数は 120000'
        When call declare -p FF_MAX_FILES_BYTES FF_MAX_PATTERNS_BYTES
        The status should equal 0
        The line 1 of output should equal 'declare -r FF_MAX_FILES_BYTES="120000"'
        The line 2 of output should equal 'declare -r FF_MAX_PATTERNS_BYTES="120000"'
        The stderr should equal ''
      End

      It '[Normal] T-FF-CBL-02: 上限ちょうどを受け付ける'
        When call check_byte_limit files "$_CBL_ASCII_MAX_TEXT" "$FF_MAX_FILES_BYTES"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-CBL-03: 小さい値を受け付ける'
        When call check_byte_limit files a.sh "$FF_MAX_FILES_BYTES"
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: CBL-04 a files value one byte over the limit is reported
    #         (nothing is printed to stdout),
    #         CBL-05 a patterns value over the limit is reported as patterns
    Context 'When: 異常系'
      It '[Error] T-FF-CBL-04: files が 120001 バイトならエラー'
        When call check_byte_limit files "$_CBL_ASCII_OVER_TEXT" "$FF_MAX_FILES_BYTES"
        The status should equal 1
        The stderr should equal "::error::files: exceeds the limit of 120000 bytes (got: '120001')"
        The output should equal ''
      End

      It '[Error] T-FF-CBL-05: patterns が 120001 バイトならエラー'
        When call check_byte_limit patterns "$_CBL_ASCII_OVER_TEXT" "$FF_MAX_PATTERNS_BYTES"
        The status should equal 1
        The stderr should start with "::error::patterns: exceeds the limit of 120000 bytes"
        The lines of stderr should equal 1
      End
    End

    # エッジケース: CBL-06 multibyte text in a UTF-8 caller locale is counted
    #               in bytes, not characters,
    #               CBL-07 multibyte text of exactly the limit in bytes is accepted,
    #               CBL-08 the caller's LC_ALL is not changed by the check
    Context 'When: エッジケース'
      It '[Edge] T-FF-CBL-06: 日本語 40001 字 (120003 バイト) はエラー'
        When call _cbl_check_in_utf8 files "$_CBL_KANA_OVER_TEXT" "$FF_MAX_FILES_BYTES"
        The status should equal 1
        The stderr should include "(got: '120003')"
        The stderr should start with "::error::files:"
      End

      It '[Edge] T-FF-CBL-07: 日本語 40000 字 (120000 バイト) は受け付ける'
        When call _cbl_check_in_utf8 files "$_CBL_KANA_MAX_TEXT" "$FF_MAX_FILES_BYTES"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-CBL-08: 呼び出し元のロケールを変えない'
        When call _cbl_lc_all_after_check
        The status should equal 0
        The output should equal 'C.UTF-8'
        The stderr should equal ''
      End
    End
  End

  ##
  # check_line_limit: check that one input (files or patterns) is within its
  # line-count limit, counted after blank lines are dropped.
  # Assigned test IDs: T-FF-CLL-01, T-FF-CLL-02, T-FF-CLL-03, T-FF-CLL-04,
  #                    T-FF-CLL-05, T-FF-CLL-06, T-FF-CLL-07, T-FF-CLL-08
  # Scenarios: the line-limit constants FF_MAX_FILES and FF_MAX_PATTERNS are
  #            3000 and 100 and readonly (status 0, empty stderr); files
  #            lines of exactly FF_MAX_FILES (3000) and patterns lines of
  #            exactly FF_MAX_PATTERNS (100) are accepted (status 0, empty
  #            stderr); files lines of FF_MAX_FILES + 1 (3001) and patterns
  #            lines of FF_MAX_PATTERNS + 1 (101) are rejected (status 1,
  #            one ::error::<name>: line with the line count); an empty text
  #            is 0 lines and is accepted (status 0, empty stderr); one line
  #            without a trailing LF is 1 line and is accepted at a limit of
  #            1 (status 0, empty stderr); two lines are counted as 2 and are
  #            rejected at a limit of 1 (status 1, one ::error::files: line
  #            with got: '2').
  Describe 'check_line_limit'
    # 正常系: CLL-01 the line-limit constants are 3000 and 100 and readonly,
    #         CLL-02 files lines of exactly 3000 accepted,
    #         CLL-03 patterns lines of exactly 100 accepted
    Context 'When: 正常系'
      It '[Normal] T-FF-CLL-01: 件数の上限の定数は 3000 と 100'
        When call declare -p FF_MAX_FILES FF_MAX_PATTERNS
        The status should equal 0
        The line 1 of output should equal 'declare -r FF_MAX_FILES="3000"'
        The line 2 of output should equal 'declare -r FF_MAX_PATTERNS="100"'
        The stderr should equal ''
      End

      It '[Normal] T-FF-CLL-02: files 3000 行を受け付ける'
        When call check_line_limit files "$_CLL_FILES_MAX_LINES" "$FF_MAX_FILES"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-CLL-03: patterns 100 行を受け付ける'
        When call check_line_limit patterns "$_CLL_PATTERNS_MAX_LINES" "$FF_MAX_PATTERNS"
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: CLL-04 files lines one over the limit (3001) are reported,
    #         CLL-05 patterns lines one over the limit (101) are reported
    #         (nothing is printed to stdout)
    Context 'When: 異常系'
      It '[Error] T-FF-CLL-04: files 3001 行はエラー'
        When call check_line_limit files "$_CLL_FILES_OVER_LINES" "$FF_MAX_FILES"
        The status should equal 1
        The stderr should equal "::error::files: exceeds the limit of 3000 lines (got: '3001')"
        The output should equal ''
      End

      It '[Error] T-FF-CLL-05: patterns 101 行はエラー'
        When call check_line_limit patterns "$_CLL_PATTERNS_OVER_LINES" "$FF_MAX_PATTERNS"
        The status should equal 1
        The stderr should equal "::error::patterns: exceeds the limit of 100 lines (got: '101')"
        The output should equal ''
      End
    End

    # エッジケース: CLL-06 an empty text is 0 lines and is accepted,
    #               CLL-07 one line without a trailing LF is 1 line and is
    #               accepted at a limit of 1,
    #               CLL-08 two lines are counted as 2 and are rejected at a
    #               limit of 1
    Context 'When: エッジケース'
      It '[Edge] T-FF-CLL-06: 空文字列は 0 行として受け付ける'
        When call check_line_limit files "" 1
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-CLL-07: 末尾に LF の無い 1 行を 1 行と数える'
        When call check_line_limit files a 1
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-CLL-08: 2 行を 2 行と数える'
        When call check_line_limit files "$_CLL_TWO_LINES" 1
        The status should equal 1
        The stderr should include "(got: '2')"
        The stderr should start with "::error::files:"
      End
    End
  End

  ##
  # check_patterns: check the parsed pattern lines (validation only; nothing
  # is printed on stdout in any case).
  # Assigned test IDs: T-FF-CP-01 .. T-FF-CP-12
  # Scenarios: a line that does not start with "!", a line that starts with
  #            "!", include and exclude lines mixed, and a line with double
  #            quotes are accepted (status 0, empty stdout, empty stderr);
  #            a line made only of "!" and an exclude whose rest starts with
  #            a space or a tab are reported (status 1, one ::error::patterns:
  #            line with the rejected line as the value, empty stdout);
  #            "!!a.sh" is accepted, since the rest after the first "!" is
  #            neither empty nor starts with whitespace; an empty input is
  #            accepted as no patterns; when two lines are rejected, only
  #            the first one is reported (status 1, one ::error::patterns:
  #            line, empty stdout); a pattern with a tab inside and a pattern
  #            that ends with a backslash are accepted (status 0, empty
  #            stdout, empty stderr).
  Describe 'check_patterns'
    # 正常系: CP-01 a line that does not start with "!" is accepted,
    #         CP-02 a line that starts with "!" is accepted,
    #         CP-03 include and exclude lines mixed are accepted,
    #         CP-04 a line with double quotes is accepted
    #         (status 0, empty stdout, empty stderr)
    Context 'When: 正常系'
      It '[Normal] T-FF-CP-01: ! で始まらない行を受け付ける'
        When call check_patterns '*.sh'
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-CP-02: ! で始まる行を受け付ける'
        When call check_patterns '!*.md'
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-CP-03: 包含と除外が混在しても受け付ける'
        When call check_patterns "$_CP_ORDERED_PATTERNS"
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-CP-04: ダブルクオートを含む行を受け付ける'
        When call check_patterns "$_CP_QUOTED_PATTERN"
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End
    End

    # 異常系: CP-05 a line made only of "!" is reported,
    #         CP-06 an exclude whose rest starts with a space is reported,
    #         CP-07 an exclude whose rest starts with a tab is reported
    Context 'When: 異常系'
      It '[Error] T-FF-CP-05: ! だけの行はエラー'
        When call check_patterns '!'
        The status should equal 1
        The stderr should start with '::error::patterns:'
        The stderr should include "(got: '!')"
        The lines of stderr should equal 1
        The output should equal ''
      End

      It '[Error] T-FF-CP-06: スペースで始まる除外はエラー'
        When call check_patterns '! a.sh'
        The status should equal 1
        The stderr should start with '::error::patterns:'
        The stderr should include "(got: '! a.sh')"
        The lines of stderr should equal 1
        The output should equal ''
      End

      It '[Error] T-FF-CP-07: タブで始まる除外はエラー'
        When call check_patterns "$_CP_TAB_EXCLUDE_PATTERN"
        The status should equal 1
        The stderr should start with '::error::patterns:'
        The lines of stderr should equal 1
        The output should equal ''
      End
    End

    # エッジケース: CP-08 "!!a.sh" is accepted (the rest after the first "!"
    #             is neither empty nor starts with whitespace),
    #             CP-09 an empty input is accepted as no patterns,
    #             CP-10 only the first of two rejected lines is reported,
    #             CP-11 a pattern with a tab inside is accepted,
    #             CP-12 a pattern that ends with a backslash is accepted
    Context 'When: エッジケース'
      It '[Edge] T-FF-CP-08: ! が 2 つ続く行を受け付ける'
        When call check_patterns '!!a.sh'
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-CP-09: 空の入力はパターン無しとして受け付ける'
        When call check_patterns ""
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-CP-10: 不正な行が 2 つあれば最初の行だけを報告する'
        When call check_patterns "$_CP_TWO_BAD_LINES"
        The status should equal 1
        The stderr should start with '::error::patterns:'
        The stderr should include "(got: '!')"
        The lines of stderr should equal 1
        The output should equal ''
      End

      It '[Edge] T-FF-CP-11: パターン内にタブを含む行を受け付ける'
        When call check_patterns "$_CP_INNER_TAB_PATTERN"
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-CP-12: 末尾がバックスラッシュの行を受け付ける'
        When call check_patterns "$_CP_BACKSLASH_PATTERN"
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End
    End
  End

  ##
  # glob_to_regex: convert one glob to an anchored ERE. Matching is done by
  # the _gtr_match helper with LC_ALL=C.UTF-8, as
  # [[ $path =~ $(glob_to_regex "$glob") ]].
  # Assigned test IDs: T-FF-GTR-01 .. T-FF-GTR-40
  # Scenarios: "*" matches zero or more characters other than "/";
  #            "**" crosses directory levels ("**/" matches zero or more
  #            levels, a trailing "/**" matches one or more characters);
  #            "?" matches exactly one character other than "/";
  #            the ERE is anchored, so a glob must match the whole path;
  #            ".", "[", "]", "+", "(", ")", "\", '"' and "|" match only
  #            themselves (brackets are not a character class);
  #            boundaries of "**" ("**/**", "a/**/**/b", "a**/b", "a**b",
  #            "***.sh");
  #            "?" matches one UTF-8 character, a leading "." is matched
  #            like any other character, and matching is case-sensitive.
  Describe 'glob_to_regex'
    # 正常系: GTR-01 "*" matches a file name without "/",
    #         GTR-02 "*" does not match across "/",
    #         GTR-03 "**" alone matches a file name,
    #         GTR-04 "**" alone matches a path across "/",
    #         GTR-05 a leading "**/" matches zero directory levels,
    #         GTR-06 a leading "**/" matches one directory level,
    #         GTR-07 a leading "**/" matches two directory levels,
    #         GTR-08 a trailing "/**" matches a file under the directory,
    #         GTR-09 a trailing "/**" matches a file in a subdirectory,
    #         GTR-10 a "**/" after "/" matches zero directory levels,
    #         GTR-11 a "**/" after "/" matches two directory levels,
    #         GTR-12 "?" matches one character other than "/",
    #         GTR-13 "?" does not match two characters,
    #         GTR-14 a glob without wildcards matches the same string,
    #         GTR-15 a glob that matches only part of the path does not match,
    #         GTR-16 the ERE is anchored with "^" and "$" (glob_to_regex is
    #                called directly, without _gtr_match)
    Context 'When: 正常系'
      It '[Normal] T-FF-GTR-01: *.sh は a.sh に一致する'
        When call _gtr_match '*.sh' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-02: *.sh は dir/a.sh に一致しない'
        When call _gtr_match '*.sh' 'dir/a.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-03: ** は a.sh に一致する'
        When call _gtr_match '**' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-04: ** は dir/sub/a.sh に一致する'
        When call _gtr_match '**' 'dir/sub/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-05: **/a.sh は 0 階層の a.sh に一致する'
        When call _gtr_match '**/a.sh' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-06: **/a.sh は 1 階層の x/a.sh に一致する'
        When call _gtr_match '**/a.sh' 'x/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-07: **/a.sh は 2 階層の x/y/a.sh に一致する'
        When call _gtr_match '**/a.sh' 'x/y/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-08: dir/** は dir/a.sh に一致する'
        When call _gtr_match 'dir/**' 'dir/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-09: dir/** は dir/sub/a.sh に一致する'
        When call _gtr_match 'dir/**' 'dir/sub/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-10: a/**/b.sh は a/b.sh に一致する'
        When call _gtr_match 'a/**/b.sh' 'a/b.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-11: a/**/b.sh は a/x/y/b.sh に一致する'
        When call _gtr_match 'a/**/b.sh' 'a/x/y/b.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-12: dir/?.sh は dir/a.sh に一致する'
        When call _gtr_match 'dir/?.sh' 'dir/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-13: dir/?.sh は dir/ab.sh に一致しない'
        When call _gtr_match 'dir/?.sh' 'dir/ab.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-14: 同じ文字列のパスに一致する'
        When call _gtr_match 'a.sh' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-15: パスの一部だけの一致は一致としない'
        When call _gtr_match 'src' 'src/a.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Normal] T-FF-GTR-16: 変換結果は全体一致のアンカーで囲まれる'
        When call glob_to_regex '*.sh'
        The status should equal 0
        The output should start with '^'
        The output should end with '$'
        The stderr should equal ''
      End
    End

    # 異常系: GTR-17 "." does not match an arbitrary character,
    #         GTR-18 brackets are not a character class,
    #         GTR-19 brackets match themselves,
    #         GTR-20 "+" and parentheses match themselves,
    #         GTR-21 a trailing "\" matches itself,
    #         GTR-22 a trailing "\" cannot be omitted,
    #         GTR-23 double quotes match themselves (they are not removed),
    #         GTR-24 "|" is not alternation
    Context 'When: 異常系'
      It '[Error] T-FF-GTR-17: . は任意の 1 文字に一致しない'
        When call _gtr_match 'a.sh' 'aXsh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-18: ブラケットは文字クラスにならない'
        When call _gtr_match '[ab].sh' 'a.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-19: ブラケットは文字そのものに一致する'
        When call _gtr_match '[ab].sh' '[ab].sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-20: + と括弧は文字そのものに一致する'
        When call _gtr_match 'a+(b).sh' 'a+(b).sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-21: 末尾の \ は文字そのものに一致する'
        When call _gtr_match "$_GTR_BACKSLASH_GLOB" "$_GTR_BACKSLASH_PATH"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-22: 末尾の \ は省略できない'
        When call _gtr_match "$_GTR_BACKSLASH_GLOB" 'a'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-23: ダブルクオートは文字そのもの'
        When call _gtr_match "$_GTR_QUOTED_GLOB" 'b.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Error] T-FF-GTR-24: | は選択にならない'
        When call _gtr_match 'a|b' 'a'
        The status should equal 1
        The stderr should equal ''
      End
    End

    # エッジケース: GTR-25 a trailing "/**" needs at least one character after "/",
    #               GTR-26 a trailing "/**" does not match a sibling that shares
    #                      the directory name as a prefix,
    #               GTR-27 the "**" left after "**/" in "**/**" matches a file
    #                      name,
    #               GTR-28 "**/**" matches a path across "/",
    #               GTR-29 consecutive "**/" each match zero or more directory
    #                      levels,
    #               GTR-30 consecutive "**/" together match two directory levels,
    #               GTR-31 a "**/" not right after "/" is "**" plus a literal "/",
    #               GTR-32 a "**/" not right after "/" does not cross "/",
    #               GTR-33 a "**" not delimited by "/" means "*",
    #               GTR-34 a "**" not delimited by "/" does not cross "/",
    #               GTR-35 "***" is read as "**" then "*" (longest match first),
    #               GTR-36 a leading "***" not followed by "/" does not cross "/",
    #               GTR-37 "?" matches one UTF-8 character (not one byte),
    #               GTR-38 "*" also matches a leading ".",
    #               GTR-39 "*" does not cross "/" to a dotfile in a directory,
    #               GTR-40 matching is case-sensitive (default shell options)
    Context 'When: エッジケース'
      It '[Edge] T-FF-GTR-25: dir/** は dir に一致しない'
        When call _gtr_match 'dir/**' 'dir'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-26: dir/** は dirx/a.sh に一致しない'
        When call _gtr_match 'dir/**' 'dirx/a.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-27: **/** は a.sh に一致する'
        When call _gtr_match '**/**' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-28: **/** は x/y/a.sh に一致する'
        When call _gtr_match '**/**' 'x/y/a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-29: a/**/**/b は a/b に一致する'
        When call _gtr_match 'a/**/**/b' 'a/b'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-30: a/**/**/b は a/x/y/b に一致する'
        When call _gtr_match 'a/**/**/b' 'a/x/y/b'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-31: / の直後ではない **/ は ax/b に一致する'
        When call _gtr_match 'a**/b' 'ax/b'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-32: / の直後ではない **/ は a/x/b に一致しない'
        When call _gtr_match 'a**/b' 'a/x/b'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-33: / に挟まれない ** は axxb に一致する'
        When call _gtr_match 'a**b' 'axxb'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-34: / に挟まれない ** は / をまたがない'
        When call _gtr_match 'a**b' 'ax/xb'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-35: ***.sh は a.sh に一致する'
        When call _gtr_match '***.sh' 'a.sh'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-36: ***.sh は d/a.sh に一致しない'
        When call _gtr_match '***.sh' 'd/a.sh'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-37: ? は UTF-8 の 1 文字に一致する'
        When call _gtr_match '?.sh' "$_GTR_MULTIBYTE_PATH"
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-38: * は先頭の . に一致する'
        When call _gtr_match '*' '.env'
        The status should equal 0
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-39: * は dir/.env に一致しない'
        When call _gtr_match '*' 'dir/.env'
        The status should equal 1
        The stderr should equal ''
      End

      It '[Edge] T-FF-GTR-40: 大文字・小文字を区別する'
        When call _gtr_match '*.SH' 'a.sh'
        The status should equal 1
        The stderr should equal ''
      End
    End
  End

  ##
  # filter_files: keep the file lines that pass the keep rule, in input order.
  # Assigned test IDs: T-FF-FF-01 .. T-FF-FF-20
  # <patterns> is the parse_patterns result (checked by check_patterns):
  # "pattern" (include) and "!pattern" (exclude) lines in input order; the
  # one leading "!" of an exclude line is removed, and a line is never split
  # at a TAB.
  # Keep rule (last match wins, DR-19): each file line is checked against
  # the patterns from the last one to the first, and the first pattern that
  # matches decides (include: kept, exclude: dropped). A line that matches
  # no pattern is kept when the first pattern is an exclude and dropped when
  # it is an include; with no patterns at all every line is kept. Input
  # order and duplicate lines are kept; the order of the pattern lines can
  # change the result.
  # Scenarios: the keep rule (include only, a later exclude over an earlier
  #            include, exclude only, empty patterns, several include
  #            patterns, a later include over an earlier exclude, an
  #            include after an exclude that brings a file back);
  #            files that are not kept (no match with an include first, a
  #            later exclude over a named include);
  #            input shape and environment: duplicate lines, empty files,
  #            shell options (globstar / extglob / nocasematch / nocaseglob),
  #            nocasematch does not change include or exclude matching, the
  #            caller's options and locale stay unchanged, the file system
  #            is not consulted, an exclude first keeps unmatched lines, a
  #            TAB is part of a pattern, and only one leading "!" is removed.
  # FF-10 .. FF-13 and FF-19 call filter_files through the _ff_* helpers,
  # which call it directly (not in a subshell) so that a change of the
  # caller's state is seen. FF-14 calls it through _ff_filter_outside_repo,
  # which runs it in a subshell in a temp dir outside any git work tree.
  Describe 'filter_files'
    # 正常系: FF-01 only the lines that match an include pattern are kept;
    #         FF-02 a later exclude pattern overrides an earlier include;
    #         FF-03 with exclude patterns only, every other line is kept;
    #         FF-04 with no patterns at all, every line is kept;
    #         FF-05 with several include patterns, input order is kept;
    #         FF-15 a later include pattern overrides an earlier exclude;
    #         FF-16 an include pattern after an exclude brings a file back
    Context 'When: 正常系'
      It '[Normal] T-FF-FF-01: 包含パターンに一致するファイルだけを残す'
        When call filter_files "$_FF_SH_MD_FILES" '*.sh'
        The status should equal 0
        The output should equal "$_FF_SH_FILES"
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-02: 後に書いた除外が先の包含を打ち消す'
        When call filter_files "$_FF_SRC_FILES" $'src/**\n!src/gen/**'
        The status should equal 0
        The output should equal 'src/a.sh'
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-03: 除外だけなら残りの全件を残す'
        When call filter_files "$_FF_SH_MD_SH_FILES" '!*.md'
        The status should equal 0
        The output should equal "$_FF_SH_FILES"
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-04: パターンが無ければ全件を残す'
        When call filter_files "$_FF_MIXED_DIR_FILES" ''
        The status should equal 0
        The output should equal "$_FF_MIXED_DIR_FILES"
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-05: 包含が複数でも出力はファイルの入力順'
        When call filter_files "$_FF_UNSORTED_FILES" "$_FF_SH_MD_PATTERNS"
        The status should equal 0
        The output should equal "$_FF_UNSORTED_FILES"
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-15: 後に書いた包含が先の除外を打ち消す'
        When call filter_files "$_FF_SRC_FILES" $'!src/gen/**\nsrc/**'
        The status should equal 0
        The output should equal "$_FF_SRC_FILES"
        The stderr should equal ''
      End

      It '[Normal] T-FF-FF-16: 除外の後に書いた包含でファイルを戻せる'
        When call filter_files "$_FF_KEEP_FILES" $'src/**\n!src/gen/**\nsrc/gen/keep.sh'
        The status should equal 0
        The output should equal $'src/a.sh\nsrc/gen/keep.sh'
        The stderr should equal ''
      End
    End

    # 異常系: FF-06 a line that matches no pattern is dropped when the first
    #         pattern is an include, and nothing (not even a LF) is printed
    #         when no line is kept;
    #         FF-07 a line named by an include pattern is still dropped when
    #         it matches a later exclude pattern
    Context 'When: 異常系'
      It '[Error] T-FF-FF-06: どれにも一致しなければ空を返す'
        When call filter_files 'a.md' '*.sh'
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End

      It '[Error] T-FF-FF-07: 包含に名指しされても、後の除外に一致すれば捨てる'
        When call filter_files 'src/gen/b.sh' $'src/gen/b.sh\n!src/gen/**'
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End
    End

    # エッジケース: FF-08 duplicate lines are kept (not removed);
    #             FF-09 empty files give empty output (not even a LF);
    #             FF-10 the result does not change with globstar / extglob /
    #             nocasematch / nocaseglob enabled in the caller;
    #             FF-11 matching stays case-sensitive with nocasematch
    #             enabled in the caller;
    #             FF-12 nocasematch enabled in the caller is still enabled
    #             after the call;
    #             FF-13 "?" matches one UTF-8 character with LC_ALL=C in the
    #             caller, and the caller's LC_ALL is still C after the call;
    #             FF-14 lines are kept or dropped by the path strings alone,
    #             outside any git work tree (a missing file is kept, an
    #             existing file is not);
    #             FF-17 with an exclude pattern first, a line that matches no
    #             pattern is kept (a later include still decides the lines
    #             it matches);
    #             FF-18 a TAB inside a pattern line is part of the pattern
    #             (the line is not split at the TAB);
    #             FF-19 an exclude pattern stays case-sensitive with
    #             nocasematch enabled in the caller;
    #             FF-20 only one leading "!" of an exclude line is removed
    #             ("!!a.sh" excludes "!a.sh")
    Context 'When: エッジケース'
      It '[Edge] T-FF-FF-08: 重複を残す'
        When call filter_files "$_FF_DUPLICATE_FILES" '*.sh'
        The status should equal 0
        The output should equal "$_FF_DUPLICATE_FILES"
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-09: files が空なら空を返す'
        When call filter_files '' '*.sh'
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-10: シェルのオプションが有効でも結果が変わらない'
        When call _ff_filter_with_options "$_FF_SH_MD_FILES" '*.sh' globstar extglob nocasematch nocaseglob
        The status should equal 0
        The output should equal "$_FF_SH_FILES"
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-11: nocasematch が有効でも大文字・小文字を区別する'
        When call _ff_filter_with_options 'a.sh' '*.SH' nocasematch
        The status should equal 0
        The entire output should equal ''
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-12: 呼び出し元のシェルのオプションを変えない'
        When call _ff_nocasematch_after_call 'a.sh' '*.sh'
        The status should equal 0
        The line 1 of output should equal 'a.sh'
        The line 2 of output should equal 'nocasematch=on'
        The lines of output should equal 2
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-13: 呼び出し元のロケールが C でも UTF-8 の 1 文字で照合する'
        When call _ff_filter_in_c_locale "$_FF_MULTIBYTE_PATH" '?.sh'
        The status should equal 0
        The line 1 of output should equal "$_FF_MULTIBYTE_PATH"
        The line 2 of output should equal "LC_ALL=${_FF_C_LOCALE}"
        The lines of output should equal 2
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-14: ファイルシステムを参照せず文字列だけで判定する'
        When call _ff_filter_outside_repo "$_FF_FS_FILES" '**/*.sh'
        The status should equal 0
        The output should equal 'no/such/file.sh'
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-17: 先頭が除外なら、どれにも一致しないファイルを残す'
        When call filter_files "$_FF_DOCS_FILES" $'!*.md\ndocs/*.md'
        The status should equal 0
        The output should equal $'a.sh\ndocs/c.md'
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-18: パターン内のタブをパターンの一部として扱う'
        When call filter_files "$_FF_TAB_FILES" "$_FF_TAB_PATH"
        The status should equal 0
        The output should equal "$_FF_TAB_PATH"
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-19: nocasematch が有効でも除外パターンは大文字・小文字を区別する'
        When call _ff_filter_with_options "$_FF_MD_SH_FILES" '!*.MD' nocasematch
        The status should equal 0
        The output should equal "$_FF_MD_SH_FILES"
        The stderr should equal ''
      End

      It '[Edge] T-FF-FF-20: 除外パターンは先頭の ! を 1 つだけ除く'
        When call filter_files "$_FF_BANG_FILES" '!!a.sh'
        The status should equal 0
        The output should equal 'a.sh'
        The stderr should equal ''
      End
    End
  End

  ##
  # emit_outputs: validate the output file, then append the files and count
  # outputs, in this order.
  # Assigned test IDs: T-FF-EO-01 .. T-FF-EO-13
  # Steps: validate_output_file returning 1 is reported as the empty form of a
  # GITHUB_OUTPUT error and returning 2 as the GITHUB_OUTPUT "is not a
  # writable file" error with the path as the value, both without writing
  # anything; then files is written with write_multiline_output (one argument
  # per kept line); then count is written with write_output. A failed write
  # stops with the "failed to write" error naming that output key with the
  # path as the value, and files already written is left in place.
  # Scenarios: files and count; no kept lines; an output file that cannot be
  #            written; boundaries of the values and of the output file.
  # Every example uses the output file and directory in the temp dir created
  # by _eo_setup. EO-08 / EO-09 call it through _eo_run_with_failing_*, which
  # replace a shared function with a stub only inside that example and
  # restore it afterwards.
  Describe 'emit_outputs'
    BeforeEach '_eo_setup'
    AfterEach '_eo_teardown'

    # 正常系: EO-01 the kept lines go to files and their count to count;
    # EO-02 files is written before count; EO-03 success returns 0 and
    # prints nothing; EO-04 no kept lines give an empty files and count=0
    Context 'When: 正常系'
      It '[Normal] T-FF-EO-01: 保持行を files に、件数を count に書く'
        When call emit_outputs "$_eo_file" "$_EO_TWO_KEPT"
        The status should equal 0
        The contents of file "$_eo_file" should equal "$_EO_TWO_KEPT_OUTPUT"
      End

      It '[Normal] T-FF-EO-02: files を count より先に書く'
        When call emit_outputs "$_eo_file" a.sh
        The status should equal 0
        The line 1 of contents of file "$_eo_file" should equal 'files<<EOF'
        The line 4 of contents of file "$_eo_file" should equal 'count=1'
        The lines of contents of file "$_eo_file" should equal 4
      End

      It '[Normal] T-FF-EO-03: 成功時は 0 を返し、stdout に何も出さない'
        When call emit_outputs "$_eo_file" a.sh
        The status should equal 0
        The output should equal ''
        The stderr should equal ''
      End

      It '[Normal] T-FF-EO-04: 0 件なら files は空、count は 0'
        When call emit_outputs "$_eo_file" ''
        The status should equal 0
        The contents of file "$_eo_file" should equal "$_EO_NO_KEPT_OUTPUT"
      End
    End

    # 異常系: each error is checked as the exact single stderr line.
    # EO-05 an empty output file path is reported in the empty form;
    # EO-06 a directory as the output file is reported as "is not a writable
    # file" with its path and nothing is created inside it; EO-07 an output
    # file whose parent directory does not exist is reported the same way;
    # EO-08 a failed files write is reported as "files: failed to write" with
    # the path and count is not written; EO-09 a failed count write is
    # reported as "count: failed to write" with the path and files is left
    # in place
    Context 'When: 異常系'
      It '[Error] T-FF-EO-05: 出力先が空ならエラー'
        When call emit_outputs '' a.sh
        The status should equal 1
        The output should equal ''
        The stderr should equal '::error::GITHUB_OUTPUT: value must not be empty'
      End

      It '[Error] T-FF-EO-06: 出力先がディレクトリならエラー'
        When call _eo_run_into_dir "$_eo_dir" a.sh
        The status should equal 1
        The output should equal ''
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '${_eo_dir}')"
        The variable _eo_dir_entries should equal 0
      End

      It '[Error] T-FF-EO-07: 親ディレクトリが無ければエラー'
        When call emit_outputs "${_eo_tmpdir}/no-such-dir/out" a.sh
        The status should equal 1
        The output should equal ''
        The stderr should equal "::error::GITHUB_OUTPUT: is not a writable file (got: '${_eo_tmpdir}/no-such-dir/out')"
      End

      It '[Error] T-FF-EO-08: files の書き込みに失敗したら count を書かない'
        When call _eo_run_with_failing_wmo "$_eo_file" a.sh
        The status should equal 1
        The output should equal ''
        The stderr should equal "::error::files: failed to write (got: '${_eo_file}')"
        The contents of file "$_eo_file" should not include 'count='
        The contents of file "$_eo_file" should not include 'files<<'
      End

      It '[Error] T-FF-EO-09: count の書き込みに失敗したら files は残る'
        When call _eo_run_with_failing_wo "$_eo_file" a.sh
        The status should equal 1
        The output should equal ''
        The stderr should equal "::error::count: failed to write (got: '${_eo_file}')"
        The contents of file "$_eo_file" should include 'files<<EOF'
        The contents of file "$_eo_file" should not include 'count='
      End
    End

    # エッジケース: EO-10 a kept line equal to EOF makes the delimiter EOF_1;
    # EO-11 1000 kept lines give count=1000 as a plain decimal integer;
    # EO-12 existing content of the output file is kept and the outputs are
    # appended after it; EO-13 a missing output file under a writable
    # directory is created by the write
    Context 'When: エッジケース'
      It '[Edge] T-FF-EO-10: 保持行に EOF があれば区切り文字を選び直す'
        When call emit_outputs "$_eo_file" "$_EO_EOF_KEPT"
        The status should equal 0
        The line 1 of contents of file "$_eo_file" should equal 'files<<EOF_1'
        The contents of file "$_eo_file" should include 'count=2'
      End

      It '[Edge] T-FF-EO-11: count は先頭ゼロ・空白の無い 10 進整数'
        When call emit_outputs "$_eo_file" "$_EO_THOUSAND_KEPT"
        The status should equal 0
        The lines of contents of file "$_eo_file" should equal 1003
        The line 1003 of contents of file "$_eo_file" should equal 'count=1000'
      End

      It '[Edge] T-FF-EO-12: 既存の内容を残して追記する'
        When call _eo_run_with_existing "$_eo_file" a.sh
        The status should equal 0
        The line 1 of contents of file "$_eo_file" should equal 'existing=1'
        The line 2 of contents of file "$_eo_file" should equal 'files<<EOF'
        The lines of contents of file "$_eo_file" should equal 5
      End

      It '[Edge] T-FF-EO-13: 存在しない出力先は書き出しで作られる'
        When call emit_outputs "${_eo_tmpdir}/out" a.sh
        The status should equal 0
        The line 4 of contents of file "${_eo_tmpdir}/out" should equal 'count=1'
      End
    End
  End

  ##
  # load guard: FILTER_FILES_LIB_LOADED marks the library as loaded, and the
  # first source loads the shared library output.lib.sh. Every example sources
  # the library in a fresh bash process (via the _fe_*_fresh_shell helpers),
  # because the spec shell has already loaded it via Include.
  # Assigned test IDs: T-FF-FE-05, T-FF-FE-06, T-FF-FE-08, T-FF-FE-13
  # Scenarios: the first source returns 0, sets the guard to 1 and defines the
  #            library's own function (ff_error) and those of output.lib.sh
  #            (validate_output_file, write_multiline_output, write_output);
  #            a second source returns 0 with empty stderr;
  #            a copy whose relative output.lib.sh is missing fails to load;
  #            a source with the guard already set returns 0 without
  #            defining ff_error.
  Describe 'load guard'
    # 正常系: sourcing in a fresh process sets the guard and defines the functions
    Context 'When: 正常系'
      It '[Normal] T-FF-FE-05: 1 回目の読み込みでガード変数が設定され、依存関数がそろう'
        When call _fe_source_lib_in_fresh_shell
        The status should equal 0
        The line 1 of output should equal 'loaded=1'
        The line 2 of output should equal 'ff_error=defined'
        The line 3 of output should equal 'validate_output_file=defined'
        The line 4 of output should equal 'write_multiline_output=defined'
        The line 5 of output should equal 'write_output=defined'
        The line 6 of output should equal 'source_status=0'
      End

      It '[Normal] T-FF-FE-06: 2 回目の読み込みでもエラーにならない'
        When call _fe_resource_lib_in_fresh_shell
        The status should equal 0
        The stderr should equal ''
      End
    End

    # 異常系: FE-08 an isolated copy without the shared library fails to load
    Context 'When: 異常系'
      BeforeEach '_fe_setup'
      AfterEach '_fe_teardown'

      It '[Error] T-FF-FE-08: output.lib.sh が見つからなければ読み込みを失敗させる'
        When call _fe_source_isolated_copy
        The status should not equal 0
        The stderr should include 'output.lib.sh'
      End
    End

    # エッジケース: FE-13 a preset guard makes the source return without defining anything
    Context 'When: エッジケース'
      It '[Edge] T-FF-FE-13: ガード変数が設定済みなら関数を定義せずに戻る'
        When call _fe_source_lib_in_fresh_shell 1
        The status should equal 0
        The output should include 'ff_error=undefined'
        The output should include 'source_status=0'
      End
    End
  End
End
