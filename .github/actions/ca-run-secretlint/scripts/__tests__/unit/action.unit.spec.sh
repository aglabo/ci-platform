#!/usr/bin/env bash
# src: .github/actions/ca-run-secretlint/scripts/__tests__/unit/action.unit.spec.sh
# @(#) : unit tests for action.yml (static checks)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash

# Test suite for action.yml
# Module: composite-action/run-secretlint (test_scope RSL)
# Target: ca-run-secretlint/action.yml (static checks)

# The YAML is read, not executed: no Include
_ACT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-run-secretlint"
_ACT_YML="${_ACT_DIR}/action.yml"

##
# Print the top-level key names of the inputs section, sorted (LC_ALL=C).
# @stdout one input name per line
# @return 1 when action.yml does not exist
_act_input_names() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_inputs = ($0 ~ /^inputs:/); next }
    in_inputs && /^  [A-Za-z0-9_-]+:/ { sub(/^  /, ""); sub(/:.*/, ""); print }
  ' "$_ACT_YML" | LC_ALL=C sort
}

##
# Print `required=<v> default=<v>` of one input, quotes removed from the values.
# @arg $1 input — input name
# @stdout the summary line (a missing key prints an empty value)
# @return 1 when action.yml does not exist
_act_input_summary() {
  [ -f "$_ACT_YML" ] || return 1
  awk -v input="$1" '
    /^[^ #]/ { in_inputs = ($0 ~ /^inputs:/); in_input = 0; next }
    in_inputs && /^  [A-Za-z0-9_-]+:/ { in_input = ($0 ~ ("^  " input ":")); next }
    in_input && /^    (required|default):/ {
      key = $1; sub(/:$/, "", key)
      sub(/^    [a-z]+:[ ]*/, ""); sub(/[ ]+$/, ""); gsub(/^"|"$/, "")
      val[key] = $0
    }
    END { printf "required=%s default=%s\n", val["required"], val["default"] }
  ' "$_ACT_YML"
}

##
# Print the runs section digest: `using=<v>`, `runs=<N> shells=<M>` (count of
# `run:` keys and of `shell: bash` keys), and each run command (`cmd=<line>`).
# `uses:` steps have neither key, so they are not counted.
# @stdout the digest lines
# @return 1 when action.yml does not exist
_act_runs_digest() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_runs = ($0 ~ /^runs:/); next }
    !in_runs { next }
    /^  using:/ { sub(/^  using:[ ]*/, ""); sub(/[ ]+$/, ""); using = $0 }
    /^(    - |      )shell:[ ]*bash[ ]*$/ { shells++ }
    /^(    - |      )run:/ { runs++; sub(/^ *(- )?run:[ ]*/, ""); cmds = cmds "cmd=" $0 "\n" }
    END { printf "using=%s\nruns=%d shells=%d\n%s", using, runs, shells, cmds }
  ' "$_ACT_YML"
}

##
# Print the step sequence of the runs section in file order: `uses=<value>` for
# each `uses:` key and `run` for each `run:` key.
# @stdout one token per line
# @return 1 when action.yml does not exist
_act_step_order() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_runs = ($0 ~ /^runs:/); next }
    !in_runs { next }
    /^(    - |      )uses:/ { sub(/^ *(- )?uses:[ ]*/, ""); sub(/[ ]+$/, ""); print "uses=" $0 }
    /^(    - |      )run:/ { print "run" }
  ' "$_ACT_YML"
}

##
# Print the `with:` entries of the steps as `KEY: value` lines (10-space
# indentation of a step-level `with:` removed), in file order.
# @stdout the with lines
# @return 1 when action.yml does not exist
_act_step_with() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_runs = ($0 ~ /^runs:/); in_with = 0; next }
    !in_runs { next }
    /^      with:[ ]*$/ { in_with = 1; next }
    in_with && /^        [A-Za-z_][A-Za-z0-9_-]*:/ { sub(/^        /, ""); sub(/[ ]+$/, ""); print; next }
    in_with && /[^ ]/ { in_with = 0 }
  ' "$_ACT_YML"
}

##
# Print the `env:` entries of the steps as `KEY: value` lines (10-space
# indentation of a step-level `env:` removed), in file order.
# @stdout the env lines
# @return 1 when action.yml does not exist
_act_step_env() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_runs = ($0 ~ /^runs:/); in_env = 0; next }
    !in_runs { next }
    /^      env:[ ]*$/ { in_env = 1; next }
    in_env && /^        [A-Za-z_][A-Za-z0-9_]*:/ { sub(/^        /, ""); sub(/[ ]+$/, ""); print; next }
    in_env && /[^ ]/ { in_env = 0 }
  ' "$_ACT_YML"
}

##
# Print every line of every `run:` body: the same-line value and, for a block
# scalar (`run: |` / `run: >`), the following lines indented deeper than the key.
# @stdout the run body lines
# @return 1 when action.yml does not exist
_act_run_bodies() {
  [ -f "$_ACT_YML" ] || return 1
  awk '
    /^[^ #]/ { in_runs = ($0 ~ /^runs:/); in_block = 0; next }
    !in_runs { next }
    in_block && (/^[ ]*$/ || match($0, /^ */) && RLENGTH > 6) { print; next }
    { in_block = 0 }
    /^(    - |      )run:/ {
      sub(/^ *(- )?run:[ ]*/, "")
      if ($0 ~ /^[|>][+-]?[0-9]?[ ]*$/) { in_block = 1 } else { print }
    }
  ' "$_ACT_YML"
}

##
# Print the lines of the action directory (tests excluded: they quote the
# patterns) that match an extended regex, case-insensitively.
# @arg $1 regex — grep -E pattern
# @stdout `<file>:<line>:<text>` for each match (blank when none)
# @return 1 when action.yml does not exist
_act_dir_matches() {
  [ -f "$_ACT_YML" ] || return 1
  grep -rniE --exclude-dir=__tests__ -e "$1" "$_ACT_DIR" || true
}

Describe 'T-RSL-ACT: ca-run-secretlint/action.yml'
  Describe 'Given: the composite action definition'
    Describe 'When: reading the inputs'
      It 'T-RSL-ACT-01: declares only pnpm-version and secretlint-version'
        When call _act_input_names
        The status should be success
        The output should equal "pnpm-version
secretlint-version"
      End

      It 'T-RSL-ACT-02: secretlint-version is optional with an explicit X.Y.Z default'
        When call _act_input_summary secretlint-version
        The status should be success
        The output should match pattern "required=false default=[0-9]*.[0-9]*.[0-9]*"
      End

      It 'T-RSL-ACT-10: pnpm-version is optional with an empty default'
        When call _act_input_summary pnpm-version
        The status should be success
        The output should equal 'required=false default='
      End
    End

    Describe 'When: reading the steps'
      It 'T-RSL-ACT-04: is a composite with one bash run step (the pnpm step has no run)'
        When call _act_runs_digest
        The status should be success
        The line 1 of output should equal "using=composite"
        The line 2 of output should equal "runs=1 shells=1"
        # shellcheck disable=SC2016
        The line 3 of output should equal 'cmd=bash "${GITHUB_ACTION_PATH}/scripts/run-secretlint.sh"'
      End

      It 'T-RSL-ACT-11: sets up pnpm before running secretlint'
        When call _act_step_order
        The status should be success
        The line 1 of output should start with 'uses=pnpm/action-setup@'
        The line 1 of output should end with '# v6.1.1'
        The line 2 of output should equal 'run'
        The lines of output should equal 2
      End

      It 'T-RSL-ACT-12: passes the pnpm-version input to the pnpm setup step'
        When call _act_step_with
        The status should be success
        # shellcheck disable=SC2016
        The output should equal 'version: ${{ inputs.pnpm-version }}'
      End

      It 'T-RSL-ACT-05: passes the inputs to the script through env'
        When call _act_step_env
        The status should be success
        # shellcheck disable=SC2016
        The line 1 of output should equal 'INPUT_SECRETLINT_VERSION: ${{ inputs.secretlint-version }}'
      End
    End

    Describe 'When: searching for forbidden settings'
      It 'T-RSL-ACT-06: the only uses: is pnpm/action-setup@v6.1.1'
        When call _act_dir_matches '^[[:space:]]*(-[[:space:]]+)?uses:'
        The status should be success
        The lines of output should equal 1
        The output should include 'pnpm/action-setup@'
        The output should include '# v6.1.1'
      End

      It 'T-RSL-ACT-13: does not check out the repository'
        When call _act_dir_matches 'actions/checkout'
        The status should be success
        The output should equal ""
      End

      It 'T-RSL-ACT-14: does not set up Node.js'
        When call _act_dir_matches 'actions/setup-node'
        The status should be success
        The output should equal ""
      End

      It 'T-RSL-ACT-07: has no write permission for contents or id-token'
        When call _act_dir_matches '(contents|id-token):[[:space:]]*write'
        The status should be success
        The output should equal ""
      End

      It 'T-RSL-ACT-08: has no secretlintrc or config input'
        When call _act_dir_matches 'secretlintrc|^  [a-z0-9_-]*config[a-z0-9_-]*:'
        The status should be success
        The output should equal ""
      End
    End

    Describe 'When: reading the run bodies'
      It 'T-RSL-ACT-09: expands no GitHub expression inside run'
        When call _act_run_bodies
        The status should be success
        The output should include 'run-secretlint.sh'
        # shellcheck disable=SC2016
        The output should not include '${{'
      End
    End
  End
End
