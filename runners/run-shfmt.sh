#!/usr/bin/env bash
# src: ./runners/run-shfmt.sh
# @(#) : shfmt runner
#
# Usage: run-shfmt.sh [--list | -l | --format] [--] [<file|dir>...]
#   No targets: checks/formats the project root (".").
#   Explicit ShellSpec spec files (*.spec.sh) are skipped; if only spec files
#   are given, shfmt is not run. Directories are passed through unchanged
#   (.editorconfig excludes spec files during the directory walk).
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

# shellcheck source=runners/libs/init-vars.lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/libs/init-vars.lib.sh"

main() {
  local mode="list"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --list | -l)
      mode="list"
      shift
      ;;
    --format)
      mode="format"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    *) break ;;
    esac
  done
  local -a targets=()
  local _target
  for _target in "${@//\\//}"; do
    [[ $_target == *.spec.sh ]] || targets+=("$_target")
  done
  if [[ $# -eq 0 ]]; then
    targets=(".")
  elif [[ ${#targets[@]} -eq 0 ]]; then
    return 0
  fi
  case "$mode" in
  list) (cd "$PROJECT_ROOT" && shfmt -ln bash -i 2 -l -- "${targets[@]}") ;;
  format) (cd "$PROJECT_ROOT" && shfmt -ln bash -i 2 -w -- "${targets[@]}") ;;
  esac
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
