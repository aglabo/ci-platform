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

  jactionlint --config-file "${globalConfig}/jactionlint/jactionlint.yaml"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
