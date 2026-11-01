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
# shellcheck source=runners/libs/init-vars.lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

# load utility library
# shellcheck source=runners/libs/utils.lib.sh
. "${SCRIPT_ROOT}/libs/utils.lib.sh"

# @description Run jactionlint with the checked-in config,
#              or with the global config when the checked-in one is absent
# @arg $@ Arguments forwarded to jactionlint
# @exitcode 78 (EXIT_CONFIG_NOT_FOUND) Config file not found
# @exitcode Exit code of jactionlint otherwise
main() {
  local configFile
  configFile="$(require_config_file 'jactionlint.yaml' 'configs/jactionlint.yaml')" || return $?

  jactionlint --config-file "$configFile" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
