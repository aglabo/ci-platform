#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/get-changed-files.sh
# @(#) : pushイベント前後の変更ファイル一覧を取得する
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_libs/filter.lib.sh"

main() {
  local _before_sha="${BEFORE_SHA:-}"
  local _after_sha="${AFTER_SHA:-}"
  local _pattern="${PATTERN:-}"

  [[ -z "$_before_sha" ]] && { echo "::error::BEFORE_SHA is required" >&2; return 1; }
  [[ -z "$_after_sha" ]] && { echo "::error::AFTER_SHA is required" >&2; return 1; }

  local _before
  _before=$(resolve_before_sha "$_before_sha")

  local _files
  if [[ -n "$_pattern" ]]; then
    _files=$(git diff --name-only --diff-filter=ACMR "$_before" "$_after_sha" -- "$_pattern")
  else
    _files=$(git diff --name-only --diff-filter=ACMR "$_before" "$_after_sha")
  fi

  local _count=0
  if [[ -n "$_files" ]]; then
    _count=$(echo "$_files" | grep -c .)
  fi

  write_multiline_output "files" "$_files"
  echo "count=${_count}" >> "${GITHUB_OUTPUT:-/dev/null}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
