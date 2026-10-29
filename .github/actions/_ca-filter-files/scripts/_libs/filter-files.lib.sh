#!/usr/bin/env bash
# src: .github/actions/_ca-filter-files/scripts/_libs/filter-files.lib.sh
# @(#) : helper functions for the _ca-filter-files composite action
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

# ============================================================================
# Load Guard / Dependencies
# ============================================================================

# Load guard: return early when this library has already been loaded. The
# guard is set only at the end of the loading below, so a failed load leaves
# it unset and the next source tries again.
[ -n "${FILTER_FILES_LIB_LOADED:-}" ] && return 0

# Directory of the shared libraries (.github/actions/_libs)
_FF_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/_libs"
# shellcheck source=.github/actions/_libs/output.lib.sh
# shellcheck disable=SC1091
. "${_FF_COMMON_LIB_DIR}/output.lib.sh" || return 1

# The shared library trusts its own guard variable, so an inherited
# OUTPUT_LIB_LOADED (e.g. exported via the job environment) makes the source
# above return 0 without defining anything. Check the shared functions this
# library calls actually exist.
for _ff_dep in validate_output_file write_multiline_output write_output; do
  if ! declare -F "$_ff_dep" >/dev/null; then
    printf 'filter-files.lib.sh: required function not defined: %s\n' "$_ff_dep" >&2
    unset _ff_dep
    return 1
  fi
done
unset _ff_dep

# Mark as loaded only now, after the shared library has been loaded and its
# functions checked (see the load guard at the top).
FILTER_FILES_LIB_LOADED=1

# ============================================================================
# Constants
# ============================================================================

# Byte limits of the files and patterns inputs (DR-16; R-IN-016 / R-IN-017),
# counted on the raw value before conversion or splitting; a value of exactly
# the limit is accepted. Defined after the load guard is set, so a second
# source returns at the guard and never re-runs readonly (which would fail).
readonly FF_MAX_FILES_BYTES=120000
readonly FF_MAX_PATTERNS_BYTES=120000

# Line-count limits of the files and patterns inputs (DR-16; R-IN-014 /
# R-IN-015), counted after blank lines are dropped; a count of exactly the
# limit is accepted. Defined after the load guard is set, so a second source
# returns at the guard and never re-runs readonly (which would fail).
readonly FF_MAX_FILES=3000
readonly FF_MAX_PATTERNS=100

# ERE that matches a whole line of well-formed UTF-8, following the RFC 3629
# table (overlong forms, surrogates and code points above U+10FFFF are
# rejected). The bytes are embedded with $'...' so that this file itself
# holds no invalid bytes; NUL cannot appear in a Bash string, so the ASCII
# range starts at \x01. Built once at load time.
# Use it only under LC_ALL=C (byte-wise matching), unquoted on the right-hand
# side: [[ $_line =~ $_FF_UTF8_RE ]]
_FF_UTF8_RE=$'^([\x01-\x7f]|[\xc2-\xdf][\x80-\xbf]|\xe0[\xa0-\xbf][\x80-\xbf]|[\xe1-\xec\xee\xef][\x80-\xbf]{2}|\xed[\x80-\x9f][\x80-\xbf]|\xf0[\x90-\xbf][\x80-\xbf]{2}|[\xf1-\xf3][\x80-\xbf]{3}|\xf4[\x80-\x8f][\x80-\xbf]{2})*$'

# ============================================================================
# Error Reporting
# ============================================================================

##
# @description Emit a GitHub Actions error annotation. The form is chosen by
#              the argument count, not by the value:
#                normal form (3 args): "::error::<target>: <problem> (got: '<value>')"
#                empty form  (2 args): "::error::<target>: value must not be empty"
#              (an explicitly passed "" still uses the normal form)
#              <value> is encoded so that it stays on one line and cannot
#              inject a workflow command, in this order:
#                "%" -> "%25" (first, so the "%" in "%0D"/"%0A" is not
#                re-encoded), then CR -> "%0D", then LF -> "%0A".
#              <target> and <problem> are printed as is.
# @arg $1 target  — name of the offending input or variable (e.g. "files")
# @arg $2 problem — short description of what is wrong (e.g. "bad line");
#                   not printed in the empty form
# @arg $3 value   — optional; when omitted, the empty form is used
# @stdout (none)
# @stderr one ::error:: line
# @return 0 always (exiting non-zero is the caller's responsibility)
ff_error() {
  if [ "$#" -lt 3 ]; then
    printf "::error::%s: value must not be empty\n" "$1" >&2
    return 0
  fi
  local _value="$3"
  _value="${_value//%/%25}"
  _value="${_value//$'\r'/%0D}"
  _value="${_value//$'\n'/%0A}"
  printf "::error::%s: %s (got: '%s')\n" "$1" "$2" "$_value" >&2
}

# ============================================================================
# Public API: Raw Input Checks
# ============================================================================

##
# @description Check that one input is within its byte limit (DR-16), counted
#              on the raw value before it is converted or split. A value of
#              exactly the limit is accepted; only a value longer than
#              <max> bytes (> max) is reported via ff_error as
#              "<target>: exceeds the limit of <max> bytes (got: '<bytes>')".
#              The length is counted under a function-local LC_ALL=C, so it
#              is a byte count whatever the caller's locale is (DD-IN-11).
#              LC_ALL=C must be set in its own local statement: in a single
#              "local LC_ALL=C _bytes=${#2}" the ${#2} is expanded before
#              LC_ALL=C takes effect and counts characters.
# @arg $1 target — name of the checked input ("files" or "patterns")
# @arg $2 text   — raw value of the input
# @arg $3 max    — byte limit (FF_MAX_FILES_BYTES or FF_MAX_PATTERNS_BYTES)
# @stdout (none)
# @stderr (none) when the value is within the limit; one ::error::<target>:
#         line when it exceeds the limit
# @return 0 when the value is within the limit, 1 when it exceeds the limit
check_byte_limit() {
  local LC_ALL=C
  local _bytes=${#2}

  if ((_bytes > $3)); then
    ff_error "$1" "exceeds the limit of $3 bytes" "$_bytes"
    return 1
  fi
  return 0
}

##
# @description Check the line endings of one input before it is converted or
#              split. Text whose line breaks are LF or CRLF is accepted
#              (CRLF is not inspected here; it is converted to LF later).
#              An empty text is accepted.
#              Only a single CR right before an LF is allowed. A CR anywhere
#              else, including at the end of a last line that has no LF after
#              it, is reported via ff_error with that line as the value.
#              An accepted text is not split into lines: each CRLF is
#              replaced with LF and the result is searched for a CR. Only when a CR remains is the
#              converted text split into lines and the first line with a CR
#              located; that line is read from the original text, so the
#              value keeps its CRs.
#              Runs under a function-local LC_ALL=C (CR and LF are ASCII).
# @arg $1 target — name of the checked input ("files" or "patterns")
# @arg $2 text   — raw value of the input
# @stdout (none)
# @stderr (none) when the line endings are accepted; one ::error:: line otherwise
# @return 0 when the line endings are accepted, 1 otherwise
check_line_endings() {
  local LC_ALL=C
  local _s="${2//$'\r\n'/$'\n'}" _conv _lines _i

  if [[ $_s != *$'\r'* ]]; then
    return 0
  fi
  mapfile -t _conv <<<"$_s"
  for _i in "${!_conv[@]}"; do
    [[ ${_conv[_i]} == *$'\r'* ]] && break
  done
  mapfile -t _lines <<<"$2"
  ff_error "$1" "contains a CR not followed by LF" "${_lines[_i]}"
  return 1
}

# ============================================================================
# Public API: Parsing
# ============================================================================

##
# @description Parse the files input into a list of file lines. CRLF line
#              breaks are converted to LF; zero-length lines are dropped
#              (a line of only spaces is kept); the other lines are printed
#              as they are, in their original order (a leading "!" has no
#              special meaning here; it has one only in patterns). Trailing
#              LFs produce no empty line.
#              An empty text yields no lines without calling mapfile (DR-18).
#              Each line is checked in order, first for valid UTF-8 and then
#              for a double quote; the first line that fails is reported via
#              ff_error and nothing is printed.
#              The result is printed once, after all lines are checked.
# @arg $1 text — value of the files input
# @stdout the lines separated by LF, with no trailing LF
#         (nothing when there are no lines or on error)
# @stderr (none) on success; one ::error::files: line on error
# @return 0 on success, 1 when a line is rejected
parse_filelist() {
  local LC_ALL=C
  local _text _line _out="" _sep=""
  local -a _lines
  _text=$(_ff_split_lines "$1") || return 1
  [ -z "$_text" ] && return 0
  mapfile -t _lines <<<"$_text"
  for _line in "${_lines[@]}"; do
    [ -z "$_line" ] && continue
    if ! [[ $_line =~ $_FF_UTF8_RE ]]; then
      ff_error files "contains an invalid UTF-8 byte sequence" "$_line"
      return 1
    fi
    if [[ $_line == *\"* ]]; then
      ff_error files "contains a double quote" "$_line"
      return 1
    fi
    _out+="${_sep}${_line}"
    _sep=$'\n'
  done
  printf '%s' "$_out"
}

##
# @description Parse the patterns input into a list of pattern lines. CRLF
#              line breaks are converted to LF and the lines are printed in
#              their original order.
#              An empty text yields no lines without calling mapfile (DR-18).
#              Each line is checked in order: first for valid UTF-8, then
#              spaces and tabs (only those) are removed from both ends
#              (whitespace in the middle is kept), then a line that is empty
#              after the removal is dropped. The first line that fails the
#              UTF-8 check is reported via ff_error with the line as it was
#              before the removal, and nothing is printed.
#              A double quote and a leading "!" get no special treatment here
#              (the "!" is handled by the caller).
#              The result is printed once, after all lines are checked.
# @arg $1 text — value of the patterns input
# @stdout the lines separated by LF, with no trailing LF
#         (nothing when there are no lines or on error)
# @stderr (none) on success; one ::error::patterns: line on error
# @return 0 on success, 1 when a line is rejected
parse_patterns() {
  local LC_ALL=C
  local _text _line _out="" _sep=""
  local -a _lines
  _text=$(_ff_split_lines "$1") || return 1
  [ -z "$_text" ] && return 0
  mapfile -t _lines <<<"$_text"
  for _line in "${_lines[@]}"; do
    if ! [[ $_line =~ $_FF_UTF8_RE ]]; then
      ff_error patterns "contains an invalid UTF-8 byte sequence" "$_line"
      return 1
    fi
    # [[:blank:]] is only space and tab under LC_ALL=C
    _line="${_line#"${_line%%[![:blank:]]*}"}"
    _line="${_line%"${_line##*[![:blank:]]}"}"
    [ -z "$_line" ] && continue
    _out+="${_sep}${_line}"
    _sep=$'\n'
  done
  printf '%s' "$_out"
}

# ============================================================================
# Public API: Line-Count Checks
# ============================================================================

##
# @description Check that one input is within its line-count limit (DR-16),
#              counted on the parsed lines after blank lines are dropped
#              (DD-IN-10). <lines> is the result of parse_filelist or
#              parse_patterns: lines separated by LF, with no trailing LF
#              and no blank lines. An empty text is 0 lines and is counted
#              without calling mapfile (DR-18). A count of exactly the limit
#              is accepted; only more than <max> lines (> max) is reported
#              via ff_error as
#              "<target>: exceeds the limit of <max> lines (got: '<count>')".
# @arg $1 target — name of the checked input ("files" or "patterns")
# @arg $2 lines  — parsed lines of the input
# @arg $3 max    — line limit (FF_MAX_FILES or FF_MAX_PATTERNS)
# @stdout (none)
# @stderr (none) when the lines are within the limit; one ::error::<target>:
#         line when they exceed the limit
# @return 0 when the lines are within the limit, 1 when they exceed the limit
check_line_limit() {
  local _count=0
  local -a _lines
  if [ -n "$2" ]; then
    mapfile -t _lines <<<"$2"
    _count=${#_lines[@]}
  fi

  if ((_count > $3)); then
    ff_error "$1" "exceeds the limit of $3 lines" "$_count"
    return 1
  fi
  return 0
}

# ============================================================================
# Public API: Pattern Check / Conversion
# ============================================================================

##
# @description Check the parsed pattern lines (validation only, DR-19).
#              <lines> is the result of parse_patterns: lines separated by
#              LF, with no trailing LF and no blank lines. A line that starts
#              with "!" is an exclude pattern; <rest> is the line with the
#              one leading "!" removed (R-IN-004, DD-IN-02). Any other line
#              is an include pattern and is not checked here.
#              An empty text has no lines and is accepted without calling
#              mapfile (DR-18).
#              Each exclude line is checked in order: first a <rest> that is
#              empty (the line is only "!") is rejected (R-IN-005, DD-IN-03),
#              then a <rest> that starts with a space or a tab (only those)
#              is rejected (R-IN-009, DD-IN-04). The first rejected line is
#              reported via ff_error with the line as it is (DD-IN-05), and
#              the later lines are not checked.
#              The lines are not converted: the caller passes the
#              parse_patterns result to filter_files as is.
# @arg $1 lines — parsed lines of the patterns input
# @stdout (none)
# @stderr (none) when every line is accepted; one ::error::patterns: line
#         when a line is rejected
# @return 0 when every line is accepted, 1 when a line is rejected
check_patterns() {
  local _line _rest
  local -a _lines
  [ -z "$1" ] && return 0
  mapfile -t _lines <<<"$1"
  for _line in "${_lines[@]}"; do
    [[ $_line == '!'* ]] || continue
    _rest="${_line#!}"
    if [ -z "$_rest" ]; then
      ff_error patterns "exclude pattern is empty" "$_line"
      return 1
    fi
    if [[ $_rest == [$' \t']* ]]; then
      ff_error patterns "exclude pattern starts with whitespace" "$_line"
      return 1
    fi
  done
  return 0
}

##
# @description Convert one glob to an anchored ERE. <glob> is one pattern
#              line (an exclude pattern without its one leading "!"), used
#              as is.
#              A glob that is "**" as a whole becomes ".*" (any path,
#              across "/"). The rest of the glob is read one position at a
#              time, checked in this order: a "**/" at the start of the glob
#              or right after a "/" becomes "(.*/)?" (zero or more directory
#              levels), a "/**" that ends the glob becomes "/.+" (one or
#              more characters, across "/"), "*" becomes "[^/]*" (zero or
#              more characters other than "/", so a leading "." of a file
#              name is matched as well), "?" becomes "[^/]" (exactly
#              one character other than "/"), an ERE metacharacter
#              (. [ ] \ ( ) { } + | ^ $) is escaped with "\" so that it
#              matches only itself (brackets are not a character class) and
#              any other character (including '"', "/" and non-ASCII
#              characters) is copied as is (letters keep their case, so
#              matching is case-sensitive). The position right after a
#              converted "**/" counts as right after a "/", so a "**" left
#              there is checked again from "**/" (as in "**/**", and
#              "a/**/**/b" becomes "a/(.*/)?(.*/)?b"); any other "**" is two
#              "*", each "[^/]*". The result is wrapped in
#              "^...$" so that it must match the whole path (R-MAT-006).
#              The caller matches with LC_ALL=C.UTF-8, so "?" matches one
#              UTF-8 character (not one byte) of a non-ASCII path.
#              The conversion never fails.
# @arg $1 glob — one glob pattern
# @stdout the anchored ERE, with no trailing LF
# @stderr (none)
# @return 0
glob_to_regex() {
  local _out="" _i=0 _g="/$1"
  if [ "$1" = '**' ]; then
    _out='.*'
    _i=2
  fi
  # ${_g:_i} starts with the character before position _i ("/" at the start)
  while ((_i < ${#1})); do
    case "${_g:_i}" in
    '/**/'*)
      _out+='(.*/)?'
      _i=$((_i + 3))
      continue
      ;;
    ?'/**')
      _out+='/.+'
      break
      ;;
    ?'*'*) _out+='[^/]*' ;;
    ?'?'*) _out+='[^/]' ;;
    # ERE metacharacters: . [ ] \ ( ) { } + | ^ $
    ?[]'[.\(){}+|^$']*) _out+="\\${1:_i:1}" ;;
    *) _out+="${1:_i:1}" ;;
    esac
    _i=$((_i + 1))
  done
  printf '%s' "^${_out}\$"
}

# ============================================================================
# Public API: Filtering
# ============================================================================

##
# @description Keep the file lines that pass the keep rule. <files> and
#              <patterns> are lines separated by LF, with no trailing LF
#              (an empty text has no lines, DR-18). <files> is the
#              parse_filelist result; <patterns> is the parse_patterns
#              result (checked by check_patterns) as is: "pattern" lines are
#              include patterns and "!pattern" lines are exclude patterns,
#              in input order (DR-19). A pattern line is never split (a
#              pattern may contain a TAB).
#              Before the files are matched, each pattern is converted once
#              with glob_to_regex (DR-17, DR-18), keeping its kind and ERE
#              in input order; an exclude pattern is converted with its one
#              leading "!" removed ("!!a.sh" excludes "!a.sh").
#              Each file line is matched from the last pattern to the
#              first, and the first pattern that matches decides (last
#              match wins): an include pattern keeps the line (R-MAT-011),
#              an exclude pattern drops it (R-MAT-012). A line that matches
#              no pattern is kept when the first pattern is an exclude
#              pattern and dropped when it is an include pattern
#              (R-MAT-013). With no patterns, every line is kept
#              (R-MAT-010). The order of the pattern lines can change the
#              result.
#              Only the path strings are matched: the file system and git
#              are never consulted (REQ-F-012).
#              Kept lines are printed in input order, one printf per line,
#              so nothing (not even a LF) is printed when no line is kept.
#              An empty <files> or <patterns> has no lines and mapfile is
#              not called for it.
#              The body is a subshell, so the shell options and the locale
#              it changes do not leak to the caller. nocasematch is turned
#              off there before the kinds are decided and the files
#              matched, so matching is always case-sensitive for include
#              and exclude patterns alike (R-MAT-009, DD-MAT-06), and the
#              caller's nocasematch is left as it was.
#              LC_ALL is set to C.UTF-8 there before the kinds are decided
#              and the patterns converted and matched, so "?" and
#              "[^/]" match one UTF-8 character even when the caller's
#              locale is C (DD-MAT-05), and the caller's LC_ALL is left as
#              it was (no "local" is needed in the subshell).
# @arg $1 files — parsed file lines
# @arg $2 patterns — pattern / !pattern lines in input order
# @stdout one kept file line per line, each ending with LF (nothing when no
#         line is kept)
# @stderr (none)
# @return 0; 1 when glob_to_regex fails
filter_files() (
  local _f
  local -a _files=() _kinds=() _res=()
  shopt -u nocasematch
  LC_ALL=C.UTF-8
  _ff_read_lines _files "$1"
  _ff_globs_to_regexes _kinds _res "$2" || return 1

  for _f in "${_files[@]}"; do
    _ff_is_kept _kinds _res "$_f" && printf '%s\n' "$_f"
  done
  return 0
)

# ============================================================================
# Public API: Output
# ============================================================================

##
# @description Append the files and count outputs to <file>, in this order:
#              files, then count (DD-OUT-03).
#              <file> is checked first with validate_output_file: an empty
#              <file> is reported via ff_error in the empty form
#              (GITHUB_OUTPUT) and nothing is written (R-OUT-001); a
#              <file> that is not a writable file (a directory, or a path
#              whose parent directory does not exist, for example) is
#              reported as a GITHUB_OUTPUT error with <file> as the value and
#              nothing is written (R-OUT-002). A <file> that does not exist
#              yet under a writable directory passes the check and is
#              created by the first append (R-OUT-021).
#              <kept> is the filter_files result: kept lines separated by LF,
#              with no trailing LF (DR-18). The kept lines are written as the
#              multiline output files with write_multiline_output, one
#              argument per line (R-OUT-003), and their number as count with
#              write_output (R-OUT-005). An empty <kept> is read without
#              calling mapfile, so files gets no lines and count is 0
#              (R-OUT-004, DR-18). The delimiter is chosen and the file
#              is appended to by the shared functions of output.lib.sh.
#              When write_multiline_output fails (any non-zero status), the
#              failure is reported as a files error with <file> as the value
#              and count is not written (R-OUT-006). When write_output fails
#              (any non-zero status), the failure is reported as a count
#              error with <file> as the value; the files output already
#              written is left in place (R-OUT-006, DR-09).
#              The body is a brace group (not a subshell): it changes no
#              shell option and no locale.
# @arg $1 file — path of the output file (GITHUB_OUTPUT)
# @arg $2 kept — kept file lines
# @stdout (none)
# @stderr (none) on success; one ::error::GITHUB_OUTPUT: line when <file> is
#         empty or not a writable file; one ::error::files: or
#         ::error::count: line when that output cannot be written
# @return 0 on success, 1 when <file> is empty or not a writable file or
#         files or count cannot be written
emit_outputs() {
  local -a _lines
  local _rc=0
  validate_output_file "$1" || _rc=$?
  if [ "$_rc" -eq 1 ]; then
    ff_error GITHUB_OUTPUT
    return 1
  elif [ "$_rc" -ne 0 ]; then
    ff_error GITHUB_OUTPUT "is not a writable file" "$1"
    return 1
  fi
  _ff_read_lines _lines "$2"
  if ! write_multiline_output "$1" files "${_lines[@]}"; then
    ff_error files "failed to write" "$1"
    return 1
  fi
  if ! write_output "$1" count "${#_lines[@]}"; then
    ff_error count "failed to write" "$1"
    return 1
  fi
  return 0
}

# ============================================================================
# Internal Helpers
# ============================================================================

##
# @description Internal helper shared by parse_filelist and parse_patterns
#              (no test ID of its own; verified through their tests).
#              Convert CRLF line breaks to LF and print the text. The line
#              contents are not changed and empty lines are kept: each caller
#              applies its own rule for dropping lines.
#              Callers read the result with a command substitution, which
#              also drops any trailing LFs.
# @arg $1 text — raw value of the input
# @stdout the text with CRLF converted to LF
# @stderr (none)
# @return 0 always
_ff_split_lines() {
  printf '%s' "${1//$'\r\n'/$'\n'}"
}

##
# @description Internal helper of filter_files and emit_outputs (no test ID
#              of its own; verified through their tests). Read the LF
#              separated lines of <text> into the caller's array <name>,
#              replacing its contents. An empty text has no lines: the
#              array is left empty and mapfile is not called (DR-18).
# @arg $1 name — name of the caller's array to read the lines into
# @arg $2 text — lines separated by LF, with no trailing LF
# @stdout (none)
# @stderr (none)
# @return 0 always
_ff_read_lines() {
  local -n _ff_lines_ref="$1"
  _ff_lines_ref=()
  [ -z "$2" ] && return 0
  mapfile -t _ff_lines_ref <<<"$2"
}

##
# @description Internal helper of filter_files (no test ID of its own;
#              verified through the filter_files tests). Convert each line of
#              <patterns> once with glob_to_regex (DR-17, DR-19) and append,
#              in pattern order, its kind to the caller's array <kinds> and
#              its ERE to the caller's array <res> (the same index in both).
#              A line that starts with "!" is an exclude pattern: its kind is
#              "exclude" and the line with the one leading "!" removed is
#              converted ("!!a.sh" converts "!a.sh"). Any other line is an
#              include pattern: its kind is "include" and the whole line is
#              converted. A line is never split (a pattern may contain a
#              TAB). An empty text appends nothing without calling mapfile
#              (DR-18).
# @arg $1 kinds    — name of the caller's array to append the kinds to
#                    ("include" / "exclude")
# @arg $2 res      — name of the caller's array to append the EREs to
# @arg $3 patterns — pattern / !pattern lines in input order, separated by
#                    LF, with no trailing LF
# @stdout (none)
# @stderr (none)
# @return 0; 1 when glob_to_regex fails
_ff_globs_to_regexes() {
  local -n _ff_kinds_ref="$1" _ff_res_ref="$2"
  local _line _re
  local -a _lines
  _ff_read_lines _lines "$3"
  for _line in "${_lines[@]}"; do
    if [[ $_line == '!'* ]]; then
      _ff_kinds_ref+=(exclude)
      _line="${_line#!}"
    else
      _ff_kinds_ref+=(include)
    fi
    _re=$(glob_to_regex "$_line") || return 1
    _ff_res_ref+=("$_re")
  done
  return 0
}

##
# @description Internal helper of filter_files (no test ID of its own;
#              verified through the filter_files tests). Apply the keep rule
#              (last match wins, DR-19) to one file line: with no patterns,
#              the line is kept (R-MAT-010). Otherwise the EREs are matched
#              with the [[ =~ ]] builtin from the last one to the first, and
#              the first one that matches decides: an include pattern keeps
#              the line (R-MAT-011), an exclude pattern drops it
#              (R-MAT-012). A line that matches no ERE is kept when the
#              first pattern is an exclude pattern and dropped when it is
#              an include pattern (R-MAT-013).
# @arg $1 kinds — name of the caller's array of kinds ("include" / "exclude")
# @arg $2 res   — name of the caller's array of EREs (same order as <kinds>)
# @arg $3 line  — file line to check
# @stdout (none)
# @stderr (none)
# @return 0 when the line is kept, 1 when it is dropped
_ff_is_kept() {
  local -n _ff_kept_kinds_ref="$1" _ff_kept_res_ref="$2"
  local _i
  ((${#_ff_kept_res_ref[@]} == 0)) && return 0
  for ((_i = ${#_ff_kept_res_ref[@]} - 1; _i >= 0; _i--)); do
    if [[ $3 =~ ${_ff_kept_res_ref[_i]} ]]; then
      [ "${_ff_kept_kinds_ref[_i]}" = include ]
      return
    fi
  done
  [ "${_ff_kept_kinds_ref[0]}" = exclude ]
}
