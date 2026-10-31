#!/usr/bin/env bash
# src: runners/run-actionlint.sh
# @(#) : action lint runner
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck disable=SC1091

set -euo pipefail

# Init directory variables
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

# load utilty library
. "${SCRIPT_ROOT}/libs/utils.lib.sh"

# @description Run jactionlint with the checked-in config,
#              or with the global config when the checked-in one is absent
# @arg $@ Arguments forwarded to jactionlint
# @exitcode Exit code of jactionlint
main() {
  local globalConfig="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local localConfig="${PROJECT_ROOT}/configs/jactionlint.yaml"
  local configFile="${globalConfig}/jactionlint/jactionlint.yaml"

  # prefer the repository config, fall back to the global config
  [[ -f "${localConfig}" ]] && configFile="${localConfig}"

  jactionlint --config-file "${configFile}" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
