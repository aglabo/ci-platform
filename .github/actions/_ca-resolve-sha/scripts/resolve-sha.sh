#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-sha/scripts/resolve-sha.sh
# @(#) : resolve the before / after commit range and write it to GITHUB_OUTPUT
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

set -euo pipefail

# Directory of this script, resolved to an absolute path. dirname (not
# ${BASH_SOURCE[0]%/*}) yields "." for a path without a slash, so running
# `bash resolve-sha.sh` from this directory still finds _libs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/actions/_ca-resolve-sha/scripts/_libs/resolve-sha.lib.sh
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_libs/resolve-sha.lib.sh"

##
# @description Entry point of the _ca-resolve-sha composite action. The only
#              place that reads the environment; unset variables are treated
#              as empty. Calls, in this fixed order and stopping at the first
#              failure: normalize_commit_count -> validate_override ->
#              resolve_sha -> emit_outputs. Error lines on stderr come from
#              the library; main prints nothing itself.
# @env INPUT_COMMIT_COUNT, INPUT_BEFORE_SHA, INPUT_AFTER_SHA — action inputs
# @env GITHUB_EVENT_NAME, GITHUB_REF, GITHUB_EVENT_DELETED — event context
# @env GITHUB_BEFORE_SHA, GITHUB_AFTER_SHA — push event payload range
# @env GITHUB_BASE_SHA, GITHUB_HEAD_SHA — pull request base / head commits
# @env GITHUB_OUTPUT — step output file (before_sha / after_sha / resolution)
# @stderr one ::error:: line on error
# @return 0 on success, 1 when any stage fails
main() {
  local _n _range _before _after _resolution
  _n=$(normalize_commit_count "${INPUT_COMMIT_COUNT:-}") || return 1
  validate_override "${INPUT_BEFORE_SHA:-}" "${INPUT_AFTER_SHA:-}" >/dev/null || return 1
  _range=$(resolve_sha "${GITHUB_EVENT_NAME:-}" "$_n" \
    "${INPUT_BEFORE_SHA:-}" "${INPUT_AFTER_SHA:-}" \
    "${GITHUB_BEFORE_SHA:-}" "${GITHUB_AFTER_SHA:-}" \
    "${GITHUB_BASE_SHA:-}" "${GITHUB_HEAD_SHA:-}" \
    "${GITHUB_REF:-}" "${GITHUB_EVENT_DELETED:-}") || return 1
  read -r _before _after _resolution <<<"$_range"
  emit_outputs "${GITHUB_OUTPUT:-}" "$_before" "$_after" "$_resolution" || return 1
}

# Run main only when executed, not when sourced. `return` succeeds only while
# a file is being sourced (or inside a function), so the subshell fails when
# the script is executed. Unlike comparing ${BASH_SOURCE[0]} with $0, this does
# not depend on how the path is spelled: when bash finds the script through
# PATH, BASH_SOURCE[0] is the full path while $0 is the bare name.
if ! (return 0 2>/dev/null); then
  main "$@"
  exit $?
fi
