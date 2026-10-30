#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/__tests__/unit/action.unit.spec.sh
# @(#) : unit tests for action.yml (static checks)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Test suite for action.yml
# Module: composite-action/get-changed-files (test_scope GCF)
# Target: ca-get-changed-files/action.yml (static checks)

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
# The YAML is read, not executed: no Include
_ACT_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/action.yml"

# --- ヘルパー ---
# (none)

# --- 内部ヘルパー ---
# 定数
# The expected inputs names, sorted (LC_ALL=C), one per line; used by T-GCF-GACT-01
_ACT_INPUT_NAMES="commit-count
pattern"
# The expected outputs as `<name>: <value>`, sorted (LC_ALL=C), one per line; used by T-GCF-GACT-04
# shellcheck disable=SC2016
_ACT_OUTPUT_MAP='count: ${{ steps.filter-files.outputs.count }}
files: ${{ steps.filter-files.outputs.files }}'
# The expected step IDs of runs.steps, in file order, one per line; used by T-GCF-GACT-05
_ACT_STEP_IDS="resolve-sha
get-changed-files
filter-files"
# The expected run command of every step, in file order (R-ACT-030 to R-ACT-032); used by T-GCF-GACT-06
# shellcheck disable=SC2016
_ACT_RUNS='bash "${GITHUB_ACTION_PATH}/../_ca-resolve-sha/scripts/resolve-sha.sh"
bash "${GITHUB_ACTION_PATH}/scripts/get-changed-files.sh"
bash "${GITHUB_ACTION_PATH}/../_ca-filter-files/scripts/filter-files.sh"'
# The expected override inputs of the resolve-sha step as `KEY: value` (R-ACT-021), sorted (LC_ALL=C), one per line; used by T-GCF-GACT-07, T-GCF-GACT-19
_ACT_OVERRIDE_ENV='INPUT_AFTER_SHA: ""
INPUT_BEFORE_SHA: ""'
# The expected env of the resolve-sha step as `KEY: value` (R-ACT-020, R-ACT-021), sorted (LC_ALL=C), one per line; used by T-GCF-GACT-07
# shellcheck disable=SC2016
_ACT_RS_ENV_MAP='GITHUB_AFTER_SHA: ${{ github.sha }}
GITHUB_BASE_SHA: ${{ github.event.pull_request.base.sha }}
GITHUB_BEFORE_SHA: ${{ github.event.before }}
GITHUB_EVENT_DELETED: ${{ github.event.deleted }}
GITHUB_EVENT_NAME: ${{ github.event_name }}
GITHUB_HEAD_SHA: ${{ github.event.pull_request.head.sha }}
GITHUB_REF: ${{ github.ref }}
'"$_ACT_OVERRIDE_ENV"'
INPUT_COMMIT_COUNT: ${{ inputs.commit-count }}'
# The expected env of the get-changed-files step as `KEY: value` (R-ACT-022), sorted (LC_ALL=C), one per line; used by T-GCF-GACT-08
# shellcheck disable=SC2016
_ACT_GCF_ENV_MAP='AFTER_SHA: ${{ steps.resolve-sha.outputs.after_sha }}
BEFORE_SHA: ${{ steps.resolve-sha.outputs.before_sha }}'
# The expected env of the filter-files step as `KEY: value` (R-ACT-023), sorted (LC_ALL=C), one per line; used by T-GCF-GACT-09
# shellcheck disable=SC2016
_ACT_FF_ENV_MAP='INPUT_FILES: ${{ steps.get-changed-files.outputs.files }}
INPUT_PATTERNS: ${{ inputs.pattern }}'
# The internal resolve-sha action.yml, read as data only (no Include, no source); used by T-GCF-GACT-21
_ACT_RS_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-sha/action.yml"
# The internal filter-files action.yml, read as data only (no Include, no source); used by T-GCF-GACT-22
_ACT_FF_YML="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/action.yml"
# The directory tree of this action, searched for leftover files and definitions; used by T-GCF-GACT-17, T-GCF-GACT-18
_ACT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files"
# The library of this action that defines GCF_MAX_FILES_BYTES, read as data only (no Include, no source); used by T-GCF-GACT-23
_ACT_GCF_LIB="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-get-changed-files/scripts/_libs/get-changed-files.lib.sh"
# The internal filter-files library that defines FF_MAX_FILES_BYTES, read as data only (no Include, no source); used by T-GCF-GACT-23
_ACT_FF_LIB="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-filter-files/scripts/_libs/filter-files.lib.sh"
# The expected byte limit of the file list shared by both libraries (R-DIF-033, DR-13); used by T-GCF-GACT-23
_ACT_MAX_FILES_BYTES=120000

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
# Print the `env:` mapping of the step with the given `id:` as `KEY: value`
# lines, sorted (LC_ALL=C). The step is located by its position in
# _act_step_ids.
# Requires: none (reads _ACT_YML).
# @arg $1 id — step ID (e.g. resolve-sha)
# @stdout the sorted env lines
# @return 0 on success, 1 when action.yml does not exist or no step has the ID
_act_step_env_map_of() {
  [ -f "$_ACT_YML" ] || return 1
  local _index
  _index=$(_act_step_ids | awk -v id="$1" '$0 == id { print NR; exit }')
  [ -n "$_index" ] || return 1
  _act_step_env_map "$_index" | LC_ALL=C sort
}

##
# Print the override input lines (`INPUT_BEFORE_SHA:` / `INPUT_AFTER_SHA:`)
# of the resolve-sha step's env as `KEY: value`, sorted (LC_ALL=C).
# Requires: none (reads _ACT_YML).
# @stdout the matching env lines
# @return 0 on success, 1 when action.yml does not exist, the resolve-sha
#   step is absent, or neither line is present
_act_override_env_lines() {
  [ -f "$_ACT_YML" ] || return 1
  local _env
  _env=$(_act_step_env_map_of resolve-sha) || return 1
  printf '%s\n' "$_env" | grep -E '^INPUT_(BEFORE|AFTER)_SHA:'
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
# Print the key violations of the n-th step of the runs section (R-ACT-013),
# one per line: `<n>: shell` when the step has no `shell: bash`, `<n>: if`
# when it has `if:`, and `<n>: continue-on-error` when it has
# `continue-on-error:`. Only the step's own keys (`    - <key>:` /
# `      <key>:`) are read.
# Requires: none (reads _ACT_YML).
# @arg $1 n — step index, starting at 1
# @stdout the violation lines (blank when the step has none)
# @return 0 on success, 1 when action.yml does not exist
_act_step_key_violation() {
  [ -f "$_ACT_YML" ] || return 1
  _act_step "$1" | awk -v n="$1" '
    /^(    - |      )shell:[ ]*bash[ ]*$/ { has_bash = 1 }
    /^(    - |      )if:/ { print n ": if" }
    /^(    - |      )continue-on-error:/ { print n ": continue-on-error" }
    END { if (!has_bash) print n ": shell" }
  '
}

##
# Print the key violations (see _act_step_key_violation) of every step of the
# runs section, in file order.
# Requires: none (reads _ACT_YML).
# @stdout the violation lines of all steps (blank when no step has one)
# @return 0 on success, 1 when action.yml does not exist
_act_step_key_violations() {
  [ -f "$_ACT_YML" ] || return 1
  _act_each_step _act_step_key_violation
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
# Print the `uses:` key lines (`uses:` / `- uses:`) of the runs section, as
# they appear in the file. A step that references another action has such a
# line, so blank output means no step uses an action.
# Requires: none (reads _ACT_YML).
# @stdout the matching lines (blank when none match)
# @return 0 on success (also when no line matches), 1 when action.yml does
#   not exist
_act_runs_uses_lines() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section runs | awk '/^[[:space:]]*(-[[:space:]]+)?uses:/'
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
# Print the body of the top-level `description: |` block of action.yml (the
# block scalar lines, indentation kept).
# Requires: none (reads _ACT_YML).
# @stdout the description body lines
# @return 0 on success, 1 when action.yml does not exist
_act_description() {
  [ -f "$_ACT_YML" ] || return 1
  _act_section description
}

##
# Test whether the top-level description of action.yml contains a word, matched
# on word boundaries (`grep -w`), so a longer word such as `tags` does not
# count as `tag`.
# Requires: none (reads _ACT_YML).
# @arg $1 word — the word to look for (e.g. deleted)
# @return 0 when the word is present, 1 when it is absent or action.yml does
#   not exist
_act_description_has_word() {
  [ -f "$_ACT_YML" ] || return 1
  _act_description | grep -qw -- "$1"
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

##
# Print the outputs of the top-level outputs section as `<name>: <value>`,
# one per line, sorted (LC_ALL=C). Each value is read verbatim from the
# `    value:` line of that output's own block.
# Requires: none (reads _ACT_YML).
# @stdout the sorted `<name>: <value>` lines
# @return 0 on success, 1 when action.yml does not exist
_act_output_map() {
  [ -f "$_ACT_YML" ] || return 1
  local _name _value
  _act_child_names outputs | while IFS= read -r _name; do
    _value=$(_act_child_block outputs "$_name" | sed -n 's/^    value:[ ]*\(.*[^ ]\)[ ]*$/\1/p')
    echo "${_name}: ${_value}"
  done | LC_ALL=C sort
}

##
# Print the lines of action.yml that reference a removed SHA input
# (`inputs.before-sha` / `inputs.after-sha`), searched over the whole file,
# comment lines included, as `<line number>:<line>`.
# Requires: none (reads _ACT_YML).
# @stdout the matching lines (blank when none match)
# @return 0 on success (also when no line matches), 1 when action.yml does
#   not exist or grep fails (an unreadable file must not pass as blank)
_act_removed_input_refs() {
  [ -f "$_ACT_YML" ] || return 1
  grep -nE 'inputs\.(before|after)-sha' "$_ACT_YML"
  [ $? -le 1 ]
}

##
# Print the `env:` mapping of the step with the given `id:` in another
# action.yml as `KEY: value` lines, sorted (LC_ALL=C). The file is read
# through _act_step_env_map_of with _ACT_YML replaced only for that call
# (a prefix assignment); callers run this inside `$(...)`, so the
# replacement does not leak to them.
# Requires: none (reads the given file).
# @arg $1 file — path of the action.yml to read
# @arg $2 id — step ID (e.g. resolve-sha)
# @stdout the sorted env lines
# @return 0 on success, 1 when the file does not exist or no step has the ID
_act_step_env_map_in() {
  [ -f "$1" ] || return 1
  _ACT_YML="$1" _act_step_env_map_of "$2"
}

##
# Print the resolve-sha step's env of another action.yml as `KEY: value`
# lines, sorted (LC_ALL=C), with the `INPUT_BEFORE_SHA:` / `INPUT_AFTER_SHA:`
# lines removed (read through _act_step_env_map_in).
# Requires: none (reads the given file).
# @arg $1 file — path of the action.yml to read
# @stdout the env lines without the override inputs
# @return 0 on success, 1 when the file does not exist, the resolve-sha step
#   is absent, its env is empty, or no line remains
_act_rs_env_of() {
  [ -f "$1" ] || return 1
  local _env _rest
  _env=$(_act_step_env_map_in "$1" resolve-sha) || return 1
  [ -n "$_env" ] || return 1
  _rest=$(printf '%s\n' "$_env" | grep -vE '^INPUT_(BEFORE|AFTER)_SHA:')
  [ -n "$_rest" ] || return 1
  printf '%s\n' "$_rest"
}

##
# Print the env variable names of the filter-files step of another
# action.yml, sorted (LC_ALL=C), one per line (read through
# _act_step_env_map_in).
# Requires: none (reads the given file).
# @arg $1 file — path of the action.yml to read
# @stdout the env variable names
# @return 0 on success, 1 when the file does not exist, the filter-files step
#   is absent, or its env is empty
_act_ff_env_names_of() {
  [ -f "$1" ] || return 1
  local _env
  _env=$(_act_step_env_map_in "$1" filter-files) || return 1
  [ -n "$_env" ] || return 1
  printf '%s\n' "$_env" | sed 's/:.*//'
}

##
# Print the diff between the resolve-sha step's env of action.yml and that of
# the internal _ca-resolve-sha action.yml (_ACT_RS_YML), both without the
# override inputs (see _act_rs_env_of) (R-ACT-040, DR-12).
# Requires: none (reads _ACT_YML and _ACT_RS_YML).
# @stdout the diff lines (blank when both sides match)
# @return 0 when both sides match, 1 when either file does not exist, either
#   side is empty, or the two sides differ
_act_rs_env_diff() {
  [ -f "$_ACT_YML" ] || return 1
  local _ours _theirs
  _ours=$(_act_rs_env_of "$_ACT_YML") || return 1
  _theirs=$(_act_rs_env_of "$_ACT_RS_YML") || return 1
  diff <(printf '%s\n' "$_ours") <(printf '%s\n' "$_theirs")
}

##
# Print the diff between the env variable names of the filter-files step of
# action.yml and those of the internal _ca-filter-files action.yml
# (_ACT_FF_YML), both sorted (LC_ALL=C) (see _act_ff_env_names_of)
# (R-ACT-041, DR-12).
# Requires: none (reads _ACT_YML and _ACT_FF_YML).
# @stdout the diff lines (blank when both sides match)
# @return 0 when both sides match, 1 when either file does not exist, either
#   side is empty, or the two sides differ
_act_ff_env_name_diff() {
  [ -f "$_ACT_YML" ] || return 1
  local _ours _theirs
  _ours=$(_act_ff_env_names_of "$_ACT_YML") || return 1
  _theirs=$(_act_ff_env_names_of "$_ACT_FF_YML") || return 1
  diff <(printf '%s\n' "$_ours") <(printf '%s\n' "$_theirs")
}

##
# Print the paths of every file named `filter.lib.sh` (the removed legacy
# library) under the action's directory tree (_ACT_DIR) (R-DIF-030, R-DIF-032).
# Requires: none (reads _ACT_DIR).
# @stdout the matching paths (blank when none is found)
# @return 0 on success (also when nothing is found), 1 when _ACT_DIR does not
#   exist
_act_find_legacy_lib() {
  [ -d "$_ACT_DIR" ] || return 1
  find "$_ACT_DIR" -name filter.lib.sh -print
}

##
# Print the definition lines of the legacy functions (resolve_sha_for_event /
# resolve_before_sha / write_multiline_output), in the `name()`, `name ()`
# and `function name()` forms, found in the `.sh` files under the action's
# directory tree (_ACT_DIR), `__tests__` excluded, as `<path>:<line
# number>:<line>` (R-DIF-032, AC-016). A call or a mention of a name is not
# a definition, so it does not match.
# Requires: none (reads _ACT_DIR).
# @stdout the matching lines (blank when none match)
# @return 0 on success (also when no line matches), 1 when _ACT_DIR does not
#   exist, or find / grep fails (an unreadable file must not pass as blank)
_act_legacy_function_defs() {
  [ -d "$_ACT_DIR" ] || return 1
  local _files
  _files=$(find "$_ACT_DIR" -name '*.sh' -not -path '*/__tests__/*') || return 1
  [ -n "$_files" ] || return 0
  local -a _list
  mapfile -t _list <<<"$_files"
  grep -nHE '^[[:space:]]*(function[[:space:]]+)?(resolve_sha_for_event|resolve_before_sha|write_multiline_output)[[:space:]]*\(\)' "${_list[@]}"
  [ $? -le 1 ]
}

##
# Print the value of a numeric constant from its `readonly <name>=<digits>`
# line in a library file (R-DIF-033, DR-13). The value is checked statically:
# the library is read as text, never sourced (impl-note DD-DIF-03).
# Requires: none (reads the given file).
# @arg $1 file — path of the library to read
# @arg $2 name — constant name (e.g. GCF_MAX_FILES_BYTES)
# @stdout the constant's value
# @return 0 on success, 1 when the file does not exist or no such line is found
_act_limit_value() {
  [ -f "$1" ] || return 1
  local _value
  _value=$(sed -n "s/^readonly $2=\([0-9][0-9]*\)\$/\1/p" "$1")
  [ -n "$_value" ] || return 1
  printf '%s\n' "$_value"
}

##
# Print FF_MAX_FILES_BYTES of the internal _ca-filter-files library
# (_ACT_FF_LIB), read through _act_limit_value without sourcing it
# (impl-note DD-DIF-03).
# Requires: none (reads _ACT_FF_LIB).
# @stdout the constant's value
# @return 0 on success, 1 when the file does not exist or the line is not found
_act_ff_limit_value() {
  _act_limit_value "$_ACT_FF_LIB" FF_MAX_FILES_BYTES
}

# --- テスト本体 ---
##
# ca-get-changed-files: the public composite action that resolves the commit
# range of the triggering event, lists the files changed in it, and filters
# them by glob patterns, chaining the internal actions' scripts.
Describe 'ca-get-changed-files'
  ##
  # Static checks on action.yml, extracted section by section; the YAML is
  # read, not executed.
  # Scenarios: the inputs are exactly commit-count and pattern, so the old
  # before-sha / after-sha inputs are gone; commit-count is optional with the
  # default "1"; pattern is optional with the default ""; the outputs are
  # exactly files and count, bound to the filter-files step's outputs; the
  # steps are exactly resolve-sha, get-changed-files and filter-files, in
  # that order; each step runs its script under GITHUB_ACTION_PATH (the
  # internal actions' scripts through relative paths); the resolve-sha step's
  # env is exactly the internal action's GITHUB_* lines plus commit-count and
  # empty before / after SHAs; the get-changed-files step's env is exactly
  # the before / after SHAs from the resolve-sha step, so PATTERN is gone;
  # the filter-files step's env is exactly the get-changed-files step's files
  # and the pattern input; the description states that the caller's checkout
  # needs fetch-depth: 0, that a partial clone is not supported, that a
  # push of a deleted branch or of a tag is not supported, and that the
  # target repository is checked out into GITHUB_WORKSPACE without the
  # checkout path input; no step's run contains `${{`, so expressions reach
  # the scripts only through env (script injection prevention); no step
  # references an action with `uses:`, so the internal actions are reached
  # only through their scripts; every step runs with `shell: bash` and has
  # neither `if:` nor `continue-on-error:`, so no step is skipped and a
  # failing step fails the action; no file named filter.lib.sh (the removed
  # legacy library) remains under the action's directory tree; no `.sh` file
  # there, tests aside, defines the legacy functions resolve_sha_for_event,
  # resolve_before_sha or write_multiline_output; nothing in
  # the file, comments included, references the removed inputs.before-sha /
  # inputs.after-sha; the resolve-sha step's env, apart from the before /
  # after SHA overrides, matches the internal _ca-resolve-sha action's env
  # line for line; the filter-files step's env variable names match those of
  # the internal _ca-filter-files action; the file list byte limit
  # GCF_MAX_FILES_BYTES equals FF_MAX_FILES_BYTES of _ca-filter-files.
  Describe 'action.yml と配下の静的検査'
    # 正常系: the declared contract of action.yml
    Context 'When: 正常系'
      It '[Normal] T-GCF-GACT-01: 入力は commit-count と pattern だけ'
        When call _act_input_names
        The status should be success
        The output should equal "$_ACT_INPUT_NAMES"
      End

      It '[Normal] T-GCF-GACT-02: commit-count は任意で既定値 "1"'
        When call _act_input_contract commit-count
        The status should be success
        The output should equal 'commit-count required=false default="1"'
      End

      It '[Normal] T-GCF-GACT-03: pattern は任意で既定値 ""'
        When call _act_input_contract pattern
        The status should be success
        The output should equal 'pattern required=false default=""'
      End

      It '[Normal] T-GCF-GACT-04: 出力は filter-files の step の出力を値とする'
        When call _act_output_map
        The status should be success
        The output should equal "$_ACT_OUTPUT_MAP"
      End

      It '[Normal] T-GCF-GACT-05: step は 3 つで、id の順は resolve-sha → get-changed-files → filter-files'
        When call _act_step_ids
        The status should be success
        The output should equal "$_ACT_STEP_IDS"
        The result of function _act_step_count should equal 3
      End

      It '[Normal] T-GCF-GACT-06: 各 step は決められたスクリプトを実行する'
        When call _act_all_runs
        The status should be success
        The output should equal "$_ACT_RUNS"
      End

      It '[Normal] T-GCF-GACT-07: resolve-sha の step の env'
        When call _act_step_env_map_of resolve-sha
        The status should be success
        The output should equal "$_ACT_RS_ENV_MAP"
      End

      It '[Normal] T-GCF-GACT-08: get-changed-files の step の env'
        When call _act_step_env_map_of get-changed-files
        The status should be success
        The output should equal "$_ACT_GCF_ENV_MAP"
      End

      It '[Normal] T-GCF-GACT-09: filter-files の step の env'
        When call _act_step_env_map_of filter-files
        The status should be success
        The output should equal "$_ACT_FF_ENV_MAP"
      End

      It '[Normal] T-GCF-GACT-10: description に fetch-depth: 0 の必要が書かれている'
        When call _act_description
        The status should be success
        The output should include 'fetch-depth: 0'
      End

      It '[Normal] T-GCF-GACT-11: description に partial clone の不可が書かれている'
        When call _act_description
        The status should be success
        The output should include 'partial clone'
      End

      It '[Normal] T-GCF-GACT-12: description にブランチ削除とタグの push の除外が書かれている'
        When call _act_description_has_word deleted
        The status should be success
        Assert _act_description_has_word tag
      End

      It '[Normal] T-GCF-GACT-13: description に作業ディレクトリへの checkout と path 不使用が書かれている'
        When call _act_description
        The status should be success
        The output should include 'GITHUB_WORKSPACE'
        Assert _act_description_has_word path
      End
    End

    # 異常系: what action.yml must not contain
    Context 'When: 異常系'
      It '[Error] T-GCF-GACT-14: run に ${{ を含まない'
        When call _act_all_runs
        The status should be success
        The output should be present
        The output should not include '${{'
      End

      It '[Error] T-GCF-GACT-15: 内部 Action を uses で参照しない'
        When call _act_runs_uses_lines
        The status should be success
        The output should be blank
        The result of function _act_step_count should equal 3
      End

      It '[Error] T-GCF-GACT-16: 全 step が shell: bash で、if と continue-on-error を持たない'
        When call _act_step_key_violations
        The status should be success
        The output should be blank
        The result of function _act_step_count should equal 3
      End

      It '[Error] T-GCF-GACT-17: filter.lib.sh が無い'
        When call _act_find_legacy_lib
        The status should be success
        The output should be blank
      End

      It '[Error] T-GCF-GACT-18: 旧関数の定義が無い'
        When call _act_legacy_function_defs
        The status should be success
        The output should be blank
      End

      It '[Error] T-GCF-GACT-19: オーバーライドの入力は空文字列のリテラルで渡す'
        When call _act_override_env_lines
        The status should be success
        The output should equal "$_ACT_OVERRIDE_ENV"
        The output should not include '${{'
      End

      It '[Error] T-GCF-GACT-20: 削除した SHA 入力を参照しない'
        When call _act_removed_input_refs
        The status should be success
        The output should be blank
      End
    End

    # エッジケース: agreement with the internal actions' definitions
    Context 'When: エッジケース'
      It '[Edge] T-GCF-GACT-21: resolve-sha の env が _ca-resolve-sha と一致する'
        When call _act_rs_env_diff
        The status should be success
        The output should be blank
      End

      It '[Edge] T-GCF-GACT-22: filter-files の env の名前が _ca-filter-files と一致する'
        When call _act_ff_env_name_diff
        The status should be success
        The output should be blank
      End

      It '[Edge] T-GCF-GACT-23: バイト数の上限が filter-files と同じ値'
        When call _act_limit_value "$_ACT_GCF_LIB" GCF_MAX_FILES_BYTES
        The status should be success
        The output should equal "$_ACT_MAX_FILES_BYTES"
        The result of function _act_ff_limit_value should equal "$_ACT_MAX_FILES_BYTES"
      End
    End
  End
End
