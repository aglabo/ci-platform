#!/usr/bin/env bash
# src: runners/run-ghalint.sh
# @(#) : ghalint runner
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

# Init variables
# shellcheck source=runners/libs/init-vars.lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

# load utility library
# shellcheck source=runners/libs/utils.lib.sh disable=SC1091
. "${SCRIPT_ROOT}/libs/utils.lib.sh"

# @description Run ghalint (run|act) with the checked-in config,
#              or with the global config when the checked-in one is absent
# @arg $1 string Subcommand: run (workflows) or act (actions)
# @arg $@ string Remaining arguments forwarded to ghalint
# @exitcode 0 All checks passed
# @exitcode 1 Lint error or invalid subcommand
# @exitcode 78 (EXIT_CONFIG_NOT_FOUND) Config file not found
main() {
  local subcommand="${1:-}"

  case "$subcommand" in
  run | act)
    shift
    ;;
  *)
    echo "Usage: run-ghalint.sh <run|act> [args...]" >&2
    return 1
    ;;
  esac

  local -a args=("$@")
  local configFile
  configFile="$(require_config_file 'ghalint.yaml' 'configs/ghalint.yaml')" || return $?

  ghalint "$subcommand" --config "$configFile" "${args[@]+"${args[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
