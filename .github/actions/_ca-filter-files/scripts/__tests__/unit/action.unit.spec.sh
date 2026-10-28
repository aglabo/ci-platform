#!/bin/bash
# shellcheck shell=bash

# Test suite for action.yml
# Module: composite-action/filter-files (test_scope FF)
# Target: _ca-filter-files/action.yml (static checks)

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# The YAML is read, not executed: no Include
_ACT_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/action.yml"

# --- ヘルパー ---
# (none)

# --- 内部ヘルパー ---
# 定数
# The 2 step env vars required by REQ-C-005 / index §3.1; used by T-FF-ACT-01
# and T-FF-ACT-04
_ACT_ENV_VARS="INPUT_FILES INPUT_PATTERNS"
# The expected outputs names, sorted (LC_ALL=C), one per line; used by T-FF-ACT-02
_ACT_OUTPUT_NAMES="count
files"
# BRE matching the entry script in a step's run command; used by T-FF-ACT-04
_ACT_SCRIPT_RE='scripts/filter-files\.sh'

# 関数
##
# Print the body of one top-level section of action.yml (the lines after
# `<key>:` up to, not including, the next top-level key). Comment lines and
# blank lines inside the section are kept.
# Requires: none (reads _ACT_YML).
# @arg $1 key — top-level key name (e.g. runs, inputs)
# @stdout the section body lines
# @return 0 on success, 1 when action.yml does not exist
_act_section() {
  [ -f "$_ACT_YML" ] || return 1
  awk -v key="$1" '
    /^[^ #]/ { in_section = ($0 ~ ("^" key ":")); next }
    in_section { print }
  ' "$_ACT_YML"
}

##
# Count the steps (`    - ` list items) of the runs section.
# Requires: none (reads _ACT_YML).
# @stdout the number of steps
# @return 0 on success, 1 when action.yml does not exist
_act_step_count() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section runs | awk '/^    - / { n++ } END { print n + 0 }'
}

##
# Print the lines of the n-th step (1-based) of the runs section, from its
# `    - ` line up to, not including, the next step or the end of the section.
# Requires: none (reads _ACT_YML).
# @arg $1 n — step index, starting at 1
# @stdout the step lines
# @return 0 on success, 1 when action.yml does not exist
_act_step() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section runs | awk -v want="$1" '
    /^    - / { idx++; cur = (idx == want) }
    /[^ ]/ { match($0, /^ */); if (RLENGTH <= 4 && $0 !~ /^    - /) cur = 0 }
    cur { print }
  '
}

##
# Print the `env:` mapping of the n-th step of the runs section as
# `KEY: value` lines, one per direct child of `env:` (8-space indent), with
# the indentation and trailing blanks removed and the value kept verbatim.
# Requires: none (reads _ACT_YML).
# @arg $1 n — step index, starting at 1
# @stdout the env lines in file order
# @return 0 on success, 1 when action.yml does not exist
_act_step_env_map() {
  [ -f "$_ACT_YML" ] || return 1
  _act_step "$1" | awk '
    /^(    - |      )env:[ ]*$/ { in_env = 1; next }
    in_env && /^        [A-Za-z_][A-Za-z0-9_]*:/ {
      sub(/^        /, ""); sub(/[ ]+$/, ""); print; next
    }
    in_env && /[^ ]/ { match($0, /^ */); if (RLENGTH < 8) in_env = 0 }
  '
}

##
# Print the keys of the `env:` mapping of the n-th step of the runs section,
# one per line. Only direct children of `env:` (8-space indent) are printed
# (the keys of _act_step_env_map).
# Requires: none (reads _ACT_YML).
# @arg $1 n — step index, starting at 1
# @stdout the env var names
# @return 0 on success, 1 when action.yml does not exist
_act_step_env_keys() {
  [ -f "$_ACT_YML" ] || return 1
  _act_step_env_map "$1" | sed 's/:.*//'
}

##
# Run a command once for every step of the runs section, in file order,
# passing the 1-based step index as its last argument.
# Requires: none (reads _ACT_YML).
# @arg $@ command — function name and leading arguments (e.g. _act_step_run)
# @stdout the concatenated output of the command for all steps
# @return 0 on success, 1 when action.yml does not exist or the command fails
_act_each_step() {
  [ -f "$_ACT_YML" ] || return 1
  local _count _i
  _count=$(_act_step_count) || return 1
  _i=1
  while [ "$_i" -le "$_count" ]; do
    "$@" "$_i" || return 1
    _i=$((_i + 1))
  done
}

##
# Print each name of _ACT_ENV_VARS that no step of the runs section maps in
# its `env:`, one per line.
# Requires: none (reads _ACT_YML).
# @stdout the missing env var names (blank when all are present)
# @return 0 on success, 1 when action.yml does not exist
_act_missing_env_vars() {
  [ -f "$_ACT_YML" ] || return 1
  local _keys _var
  _keys=$(_act_each_step _act_step_env_keys) || return 1
  for _var in $_ACT_ENV_VARS; do
    printf '%s\n' "$_keys" | grep -qx "$_var" || echo "$_var"
  done
}

##
# Print the direct child key names (2-space indent) of one top-level section
# of action.yml, one per line, in file order.
# Requires: none (reads _ACT_YML).
# @arg $1 key — top-level key name (e.g. inputs, outputs)
# @stdout the child key names
# @return 0 on success, 1 when action.yml does not exist
_act_child_names() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section "$1" | sed -n 's/^  \([^ #][^:]*\):.*$/\1/p'
}

##
# Print the names under the top-level `outputs` section, sorted, one per line.
# Requires: none (reads _ACT_YML).
# @stdout the sorted output names
# @return 0 on success, 1 when action.yml does not exist
_act_output_names() {
  [ -f "$_ACT_YML" ] || return 1
  _act_child_names outputs | LC_ALL=C sort
}

##
# Print the `id:` of every step of the runs section, one per line, in file
# order. Both `    - id: x` and `      id: x` forms are read; quotes are removed.
# Requires: none (reads _ACT_YML).
# @stdout the step IDs
# @return 0 on success, 1 when action.yml does not exist
_act_step_ids() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section runs | awk '
    /^(    - |      )id:/ {
      sub(/^ *(- )?id:[ ]*/, ""); gsub(/["'\'']/, ""); sub(/[ ]+$/, ""); print
    }
  '
}

##
# Print each step ID referenced as `steps.<id>.` by a `value:` of the top-level
# outputs section that no step of the runs section declares, sorted and unique,
# one per line.
# Requires: none (reads _ACT_YML).
# @stdout the dangling step IDs (blank when every reference resolves)
# @return 0 on success, 1 when action.yml does not exist
_act_dangling_output_refs() {
  [ -f "$_ACT_YML" ] || return 1
  local _ids _ref
  _ids=$(_act_step_ids) || return 1
  _act_section outputs | awk '
    /^    value:/ {
      while (match($0, /steps\.[A-Za-z0-9_-]+\./)) {
        print substr($0, RSTART + 6, RLENGTH - 7)
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' | LC_ALL=C sort -u | while IFS= read -r _ref; do
    printf '%s\n' "$_ids" | grep -qxF "$_ref" || echo "$_ref"
  done
}

##
# Print the `run:` command of the n-th step of the runs section. Both
# `    - run: x` and `      run: x` forms are read; for a block scalar
# (`run: |` / `run: >`) the body lines are printed with indentation removed.
# Requires: none (reads _ACT_YML).
# @arg $1 n — step index, starting at 1
# @stdout the run command lines (blank when the step has no run)
# @return 0 on success, 1 when action.yml does not exist
_act_step_run() {
  [ -f "$_ACT_YML" ] || return 1
  _act_step "$1" | awk '
    in_block && /[^ ]/ {
      match($0, /^ */); if (RLENGTH <= 6) exit
      sub(/^ +/, ""); print; next
    }
    /^(    - |      )run:/ {
      sub(/^ *(- )?run:[ ]*/, ""); sub(/[ ]+$/, "")
      if ($0 ~ /^[|>][-+]?$/) { in_block = 1; next }
      print; exit
    }
  '
}

##
# Succeed when the first step of the runs section whose `env:` maps every name
# of _ACT_ENV_VARS has a `run:` command matching _ACT_SCRIPT_RE.
# Requires: none (reads _ACT_YML).
# @stdout none
# @return 0 when that step runs the entry script; 1 when no step maps all the
#         env vars, its run does not match, or action.yml does not exist
_act_env_step_runs_script() {
  [ -f "$_ACT_YML" ] || return 1
  local _count _i _keys _complete _var
  _count=$(_act_step_count) || return 1
  _i=1
  while [ "$_i" -le "$_count" ]; do
    _keys=$(_act_step_env_keys "$_i")
    _complete=1
    for _var in $_ACT_ENV_VARS; do
      printf '%s\n' "$_keys" | grep -qx "$_var" || _complete=0
    done
    if [ "$_complete" -eq 1 ]; then
      _act_step_run "$_i" | grep -q "$_ACT_SCRIPT_RE"
      return
    fi
    _i=$((_i + 1))
  done
  return 1
}

##
# Print the `run:` command lines of every step of the runs section, in file
# order. Only run content is printed, so `${{` in `env:` / `outputs` is not
# included.
# Requires: none (reads _ACT_YML).
# @stdout the run command lines of all steps (blank when no step has a run)
# @return 0 on success, 1 when action.yml does not exist
_act_all_runs() {
  [ -f "$_ACT_YML" ] || return 1
  _act_each_step _act_step_run
}

##
# Print the body of one direct child (2-space indent) of a top-level section
# of action.yml: the lines after `  <name>:` up to, not including, the next
# direct child or the end of the section.
# Requires: none (reads _ACT_YML).
# @arg $1 key — top-level key name (e.g. inputs, outputs)
# @arg $2 name — child key name (e.g. files)
# @stdout the child block body lines (blank when the child is absent)
# @return 0 on success, 1 when action.yml does not exist
_act_child_block() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section "$1" | awk -v name="$2" '
    /^  [^ #]/ { in_child = ($0 ~ ("^  " name ":")); next }
    in_child { print }
  '
}

##
# Print the contract of one input of the top-level inputs section as
# `<name> required=<value> default=<value>`, values verbatim (quotes kept),
# read only from that input's own block.
# Requires: none (reads _ACT_YML).
# @arg $1 name — input name (e.g. files)
# @stdout the contract line
# @return 0 on success, 1 when action.yml does not exist
_act_input_contract() {
  [ -f "$_ACT_YML" ] || return 1
  local _block _required _default
  _block=$(_act_child_block inputs "$1") || return 1
  _required=$(printf '%s\n' "$_block" | sed -n 's/^    required:[ ]*\(.*[^ ]\)[ ]*$/\1/p')
  _default=$(printf '%s\n' "$_block" | sed -n 's/^    default:[ ]*\(.*[^ ]\)[ ]*$/\1/p')
  echo "$1 required=${_required} default=${_default}"
}

# --- テスト本体 ---
##
# action.yml of the internal composite action _ca-filter-files.
# Static checks on the YAML sections, extracted section by section.
# Test IDs: T-FF-ACT-01 .. T-FF-ACT-07
Describe 'action.yml'
  ##
  # Mapping of inputs / outputs / step env vars.
  # Verifies the step env passes every variable filter-files.sh reads
  # (REQ-C-005) in the same step whose run executes filter-files.sh, and the
  # outputs section declares exactly files and count, each referencing a step
  # ID that exists in the runs section.
  # Test IDs: T-FF-ACT-01 .. T-FF-ACT-04
  Describe '入出力と環境変数の対応付け'
    Context 'When: 正常系'
      It '[Normal] T-FF-ACT-01: 2 つの入力が環境変数に対応付けられている'
        When call _act_missing_env_vars
        The status should be success
        The output should be blank
      End

      It '[Normal] T-FF-ACT-02: outputs は files と count の 2 つである'
        When call _act_output_names
        The output should equal "$_ACT_OUTPUT_NAMES"
      End

      It '[Normal] T-FF-ACT-03: outputs の値は実在する step ID を参照している'
        When call _act_dangling_output_refs
        The status should be success
        The output should be blank
      End

      It '[Normal] T-FF-ACT-04: 環境変数は run を持つ同じ step にある'
        When call _act_env_step_runs_script
        The status should be success
      End
    End
  End

  ##
  # Script injection prevention (REQ-C-001).
  # Verifies no step's run content contains a `${{` expression; expressions
  # are passed through env: instead, so `${{` in env: / outputs is legitimate.
  # Test IDs: T-FF-ACT-05
  Describe 'スクリプトインジェクションの防止'
    Context 'When: 異常系'
      It '[Error] T-FF-ACT-05: run の中に式展開が無い'
        When call _act_all_runs
        The status should be success
        The output should be present
        The output should not include '${{'
      End
    End
  End

  ##
  # Required flags and default values of the inputs (index §3.1).
  # Verifies each input's required / default, read only from that input's own
  # block inside the top-level inputs section, so a value in another input
  # block or another section does not satisfy the check.
  # Test IDs: T-FF-ACT-06 .. T-FF-ACT-07
  Describe '入力の必須指定と既定値'
    Context 'When: エッジケース'
      It '[Edge] T-FF-ACT-06: files は必須'
        When call _act_input_contract files
        The output should equal 'files required=true default='
      End

      It '[Edge] T-FF-ACT-07: patterns の既定値は空を明示する'
        When call _act_input_contract patterns
        The output should equal 'patterns required=false default=""'
      End
    End
  End
End
