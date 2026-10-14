#!/usr/bin/env bash
# src: runners/docs/lint
# @(#) : docs linter runner (markdownlint + textlint)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

set -euo pipefail

# @description Run markdownlint and textlint against docs
# @arg $@ string Paths to lint (passed to both linters)
# @exitcode 0 All checks passed
# @exitcode 1 Lint error
main() {
  local -a targets=("$@")
  local globalConfig="${XDG_CONFIG_HOME:-${HOME}/.config}"

  textlint --config "${globalConfig}/linters/textlint/textlintrc.yaml" --cache --cache-location .cache/textlint/textlintcache "${targets[@]+"${targets[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
