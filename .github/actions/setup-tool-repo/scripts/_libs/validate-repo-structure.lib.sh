#!/usr/bin/env bash
# src: .github/actions/setup-tool-repo/scripts/_libs/validate-repo-structure.lib.sh
# @(#) : validate_repo_structure — チェックアウト済みリポジトリ構造検証ライブラリ
# shellcheck shell=bash

[ -n "${VALIDATE_REPO_STRUCTURE_LIB_LOADED:-}" ] && return 0
VALIDATE_REPO_STRUCTURE_LIB_LOADED=1

##
# @description Validate that a checked-out tool repo has the expected file structure.
# @arg $1 path — path to the checked-out repository root
# @return 0 on success, 1 on failure (stderr contains ::error:: message)
validate_repo_structure() {
  local _path="$1"

  if [[ ! -f "${_path}/pnpm-lock.yaml" ]]; then
    echo "::error::validate-repo-structure: pnpm-lock.yaml not found in '${_path}'" >&2
    return 1
  fi

  if [[ ! -d "${_path}/bin" ]]; then
    echo "::error::validate-repo-structure: bin/ directory not found in '${_path}'" >&2
    return 1
  fi

  return 0
}
