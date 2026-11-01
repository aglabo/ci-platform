#!/usr/bin/env bash
# src: runners/run-textlint.sh
# @(#) : textlint runner
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

# Read libraries
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

# shellcheck disable=SC1091
. "${SCRIPT_ROOT}/libs/utils.lib.sh"

# @description Run textlint with the checked-in config,
#              or with the global config when the checked-in one is absent
# @arg $@ string Paths to lint
# @exitcode 0 All checks passed
# @exitcode 1 Lint error
# @exitcode 78 (EXIT_CONFIG_NOT_FOUND) Config file not found
main() {
  local -a targets=("$@")
  local configFile
  configFile="$(require_config_file 'textlintrc.yaml' 'configs/textlintrc.yaml')" || return $?

  textlint --config "$configFile" --cache --cache-location .cache/textlint/textlintcache "${targets[@]+"${targets[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
