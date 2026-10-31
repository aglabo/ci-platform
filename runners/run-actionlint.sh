#!/usr/bin/env bash
# src: runners/run-actionlint.sh
# @(#) : action lint runner
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

main() {
  local globalConfig="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local localConfig="./configs/jactionlint.yaml"
  local configFile="${globalConfig}/jactionlint/jactionlint.yaml"

  # prefer the repository config, fall back to the global config
  [[ -f "${localConfig}" ]] && configFile="${localConfig}"

  jactionlint --config-file "${configFile}" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
