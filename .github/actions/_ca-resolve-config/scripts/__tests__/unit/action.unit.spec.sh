#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-config/scripts/__tests__/unit/action.unit.spec.sh
# @(#) : static checks for _ca-resolve-config/action.yml
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Test suite for action.yml
# Module: composite-action/resolve-config (test_scope RC)
# Target: _ca-resolve-config/action.yml (static checks)

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# The YAML is read, not executed: no Include
_ACT_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-config/action.yml"

# --- ヘルパー ---
# (none)

# --- 内部ヘルパー ---
# 定数
# Expected input names, sorted, one per line; used by T-RC-ACT-01
_ACT_INPUT_NAMES="config
global-config
local-config"
# Expected input contracts, one per line; used by T-RC-ACT-02
_ACT_INPUT_CONTRACTS='config required=false default=""
local-config required=false default=""
global-config required=false default=""'
# Expected `<output>: <value>` lines of the outputs section, sorted (LC_ALL=C);
# used by T-RC-ACT-03
_ACT_OUTPUT_MAP='config-file: ${{ steps.resolve-config.outputs.config-file }}
source: ${{ steps.resolve-config.outputs.source }}'
# BRE matching the entry script in a step's run command; used by T-RC-ACT-05
_ACT_SCRIPT_RE='scripts/resolve-config\.sh'
# Expected env lines (sorted, LC_ALL=C) of the step running resolve-config.sh,
# followed by its run command; used by T-RC-ACT-05
_ACT_SCRIPT_STEP_CONTRACT='GITHUB_WORKSPACE: ${{ github.workspace }}
INPUT_CONFIG: ${{ inputs.config }}
INPUT_GLOBAL_CONFIG: ${{ inputs.global-config }}
INPUT_LOCAL_CONFIG: ${{ inputs.local-config }}
bash "${GITHUB_ACTION_PATH}/scripts/resolve-config.sh"'

# 関数
##
# Print the body of one top-level section of action.yml (the lines after
# `<key>:` up to, not including, the next top-level key).
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
# Print the names under the top-level `inputs` section, sorted, one per line.
# Requires: none (reads _ACT_YML).
# @stdout the sorted input names
# @return 0 on success, 1 when action.yml does not exist
_act_input_names() {
  [ -f "$_ACT_YML" ] || return 1
  _act_child_names inputs | LC_ALL=C sort
}

##
# Print the body of one direct child (2-space indent) of a top-level section
# of action.yml: the lines after `  <name>:` up to, not including, the next
# direct child or the end of the section.
# Requires: none (reads _ACT_YML).
# @arg $1 key — top-level key name (e.g. inputs, outputs)
# @arg $2 name — child key name (e.g. config)
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
# Print the contract of one input as `<name> required=<value> default=<value>`,
# values verbatim (quotes kept), read only from that input's own block.
# Requires: none (reads _ACT_YML).
# @arg $1 name — input name (e.g. config)
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

##
# Print the contracts of the three inputs, one per line, via
# _act_input_contract; used by T-RC-ACT-02.
# Requires: none (reads _ACT_YML).
# @stdout the three contract lines
# @return 0 on success, 1 when action.yml does not exist
_act_input_contracts() {
  [ -f "$_ACT_YML" ] || return 1
  local _name
  for _name in config local-config global-config; do
    _act_input_contract "$_name" || return 1
  done
}

##
# Print each output of the top-level outputs section as `<name>: <value>`,
# the value read verbatim from the `    value:` line of that output's own
# block, sorted (LC_ALL=C); used by T-RC-ACT-03.
# Requires: none (reads _ACT_YML).
# @stdout the sorted output mapping lines
# @return 0 on success, 1 when action.yml does not exist
_act_output_map() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section outputs | awk '
    /^  [^ #][^:]*:/ { name = $0; sub(/^  /, "", name); sub(/:.*/, "", name); next }
    /^    value:/ { v = $0; sub(/^    value:[ ]*/, "", v); sub(/[ ]+$/, "", v); print name ": " v }
  ' | LC_ALL=C sort
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
# Print the `run:` command lines of every step of the runs section, in file
# order. Only run content is printed, so `${{` in `env:` / `outputs` is not
# included.
# Requires: none (reads _ACT_YML).
# @stdout the run command lines of all steps (blank when no step has a run)
# @return 0 on success, 1 when action.yml does not exist
_act_all_runs() {
  [ -f "$_ACT_YML" ] || return 1
  local _count _i
  _count=$(_act_step_count) || return 1
  for ((_i = 1; _i <= _count; _i++)); do
    _act_step_run "$_i" || return 1
  done
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
# Print the sorted env mapping (LC_ALL=C) and the run command of the first
# step whose `run:` matches _ACT_SCRIPT_RE; used by T-RC-ACT-05.
# Requires: none (reads _ACT_YML).
# @stdout the sorted `KEY: value` env lines, then the run command line
# @return 0 on success, 1 when no step runs the entry script or action.yml
#         does not exist
_act_script_step_contract() {
  [ -f "$_ACT_YML" ] || return 1
  local _count _i
  _count=$(_act_step_count) || return 1
  for ((_i = 1; _i <= _count; _i++)); do
    if _act_step_run "$_i" | grep -q "$_ACT_SCRIPT_RE"; then
      _act_step_env_map "$_i" | LC_ALL=C sort
      _act_step_run "$_i"
      return
    fi
  done
  return 1
}

# --- テスト本体 ---
##
# action.yml of the internal composite action _ca-resolve-config.
# Static checks on the YAML sections, extracted section by section.
# Test IDs: T-RC-ACT-01
Describe 'action.yml'
  ##
  # Structure of the inputs section.
  # Test IDs: T-RC-ACT-01
  Describe 'inputs の構造'
    Context 'When: 正常系'
      It '[Normal] T-RC-ACT-01: inputs は config / local-config / global-config の 3 つである'
        When call _act_input_names
        The status should be success
        The output should equal "$_ACT_INPUT_NAMES"
      End

      It '[Normal] T-RC-ACT-02: 3 つの input はいずれも required=false かつ default が空文字である'
        When call _act_input_contracts
        The status should be success
        The output should equal "$_ACT_INPUT_CONTRACTS"
      End
    End
  End

  ##
  # Mapping of the outputs section.
  # Verifies each output reads the same-named output of the step.
  # Test IDs: T-RC-ACT-03
  Describe 'outputs の対応付け'
    Context 'When: 正常系'
      It '[Normal] T-RC-ACT-03: outputs は config-file / source をそれぞれ step 出力に写像する'
        When call _act_output_map
        The status should be success
        The output should equal "$_ACT_OUTPUT_MAP"
      End
    End
  End

  ##
  # Script injection prevention.
  # Verifies no step's run content contains a `${{` expression; expressions
  # are passed through env: instead, so `${{` in env: / outputs is legitimate.
  # Test IDs: T-RC-ACT-04
  Describe 'スクリプトインジェクションの防止'
    Context 'When: 異常系'
      It '[Error] T-RC-ACT-04: run の中に式展開が無い'
        When call _act_all_runs
        The status should be success
        The output should be present
        The output should not include '${{'
      End

      It '[Error] T-RC-ACT-05: 入力と GITHUB_WORKSPACE は env 経由で渡し、run は GITHUB_ACTION_PATH から実行する'
        When call _act_script_step_contract
        The status should be success
        The output should equal "$_ACT_SCRIPT_STEP_CONTRACT"
      End
    End
  End
End
