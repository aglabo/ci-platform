#!/usr/bin/env bash
# src: runners/docs/lint
# @(#) : docs linter runner (markdownlint + textlint)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

# Init variables
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

# load utilty library
. "${SCRIPT_ROOT}/libs/utils.lib.sh"

# @description Run markdownlint with the checked-in config,
#              or with the global config when the checked-in one is absent
# @arg $@ string Paths to lint
# @exitcode 0 All checks passed
# @exitcode 1 Lint error
main() {
  local -a targets=("$@")
  local globalConfig="${XDG_CONFIG_HOME:-${HOME}/.config}"

  markdownlint --config "${globalConfig}/linters/markdownlint/.markdownlint-cli2.yaml" "${targets[@]+"${targets[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
