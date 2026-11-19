#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-config/scripts/resolve-config.sh
# @(#) : resolve the configuration file and write it to GITHUB_OUTPUT
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

# Directory of this script, resolved to an absolute path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_ca-resolve-config/scripts/_libs/resolve-config.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_libs/resolve-config.lib.sh"
# shellcheck source=.github/actions/_libs/output.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/../../_libs/output.lib.sh"

##
# @description Entry point of the _ca-resolve-config composite action. The only
#              place that reads the environment; unset variables are treated
#              as empty. Writes config-file and source to GITHUB_OUTPUT only
#              after resolve_config succeeded, so nothing is written on error,
#              then prints one ::notice:: line with the source and the path.
# @env INPUT_CONFIG, INPUT_LOCAL_CONFIG, INPUT_GLOBAL_CONFIG — action inputs
# @env GITHUB_WORKSPACE — base directory of relative paths
# @env GITHUB_OUTPUT — step output file (config-file / source)
# @stdout one ::notice:: line on success
# @stderr one ::error:: line on error (from the library)
# @return 0 on success, 1 on error
main() {
  local _result _path _source
  _result=$(resolve_config "${INPUT_CONFIG:-}" "${INPUT_LOCAL_CONFIG:-}" \
    "${INPUT_GLOBAL_CONFIG:-}") || return 1
  read -r _path _source <<< "$_result"
  write_output "${GITHUB_OUTPUT:-}" config-file "$_path" || return 1
  write_output "${GITHUB_OUTPUT:-}" source "$_source" || return 1
  printf '::notice::Using %s config: %s\n' "$_source" "$_path"
}

# Run main only when executed, not when sourced.
if ! (return 0 2> /dev/null); then
  main "$@"
  exit $?
fi
