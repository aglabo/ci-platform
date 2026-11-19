#!/usr/bin/env bash
# src: .github/actions/ca-run-secretlint/scripts/run-secretlint.sh
# @(#) : run secretlint through pnpm dlx with the version given by the action input
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_libs/error.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../../_libs/error.lib.sh"
# shellcheck source=.github/actions/ca-run-secretlint/scripts/_libs/inputs.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_libs/inputs.lib.sh"

main() {
  validate_secretlint_version "${INPUT_SECRETLINT_VERSION:-}" || return 1
  pnpm dlx "secretlint@${INPUT_SECRETLINT_VERSION}"
}

if ! (return 0 2> /dev/null); then
  main "$@"
  exit $?
fi
