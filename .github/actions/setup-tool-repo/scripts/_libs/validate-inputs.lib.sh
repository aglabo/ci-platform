#!/usr/bin/env bash
# src: .github/actions/setup-tool-repo/scripts/_libs/validate-inputs.lib.sh
# @(#) : validate_inputs — repo/path/ref パラメータ検証ライブラリ
# shellcheck shell=bash

[ -n "${VALIDATE_INPUTS_LIB_LOADED:-}" ] && return 0
VALIDATE_INPUTS_LIB_LOADED=1

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../../../_libs/validation.lib.sh"

##
# @description Validate repo, path, and ref input parameters.
# @arg $1 repo — "owner/repo" format (required)
# @arg $2 path — must start with "./" and contain no ".." segments (required)
# @arg $3 ref  — non-empty string (required)
# @return 0 on success, 1 on failure (stderr contains ::error:: message)
validate_inputs() {
  local _repo="$1"
  local _path="$2"
  local _ref="$3"

  validate_repo "$_repo" "repo" || return 1

  if [[ "$_path" != "./"* ]]; then
    echo "::error::validate-inputs: path must start with './' (got: '${_path}')" >&2
    return 1
  fi

  local _segment
  local -a _segments
  IFS='/' read -ra _segments <<< "$_path"
  for _segment in "${_segments[@]}"; do
    if [[ "$_segment" == ".." ]]; then
      echo "::error::validate-inputs: path must not contain '..' segments (got: '${_path}')" >&2
      return 1
    fi
  done

  if [[ -z "${_ref// /}" ]]; then
    echo "::error::validate-inputs: ref must not be empty" >&2
    return 1
  fi

  return 0
}
