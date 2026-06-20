#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool-repo/scripts/_libs/check-existing.lib.sh
# @(#) : check_existing — 既存チェックアウト確認とロック取得ライブラリ
# shellcheck shell=bash

[ -n "${CHECK_EXISTING_LIB_LOADED:-}" ] && return 0
CHECK_EXISTING_LIB_LOADED=1

##
# @description Check if a tool repo checkout already exists and acquire a lock.
# @arg $1 repo — "owner/repo" format
# @arg $2 path — directory path where the repo would be checked out
# @return 0 on success (writes skip=true/false to GITHUB_OUTPUT, REPO_LOCK_DIR to GITHUB_ENV)
# @return 1 on failure (lock conflict, missing .repo, or repo mismatch)
check_existing() {
  local _repo="$1"
  local _path="$2"
  local _lock_dir="${_path}/.repo.lock"

  # 1. Capture whether path existed before any mkdir
  local _path_existed
  [[ -d "${_path}" ]] && _path_existed=true || _path_existed=false

  # 2. Ensure parent exists so atomic lock mkdir can succeed
  mkdir -p "${_path}"

  # 3. Lock acquisition (atomic mkdir — fails if lock already exists)
  if ! mkdir "${_lock_dir}" 2>/dev/null; then
    echo "::error::check-existing: lock conflict: ${_lock_dir} already exists" >&2
    return 1
  fi

  # 4. Write REPO_LOCK_DIR to GITHUB_ENV (required in all success paths)
  echo "REPO_LOCK_DIR=${_lock_dir}" >> "${GITHUB_ENV}"

  # 5. Path exists: validate .repo
  if [[ "${_path_existed}" == true ]]; then
    # .repo missing → error
    if [[ ! -f "${_path}/.repo" ]]; then
      echo "::error::check-existing: path exists but .repo is missing: ${_path}" >&2
      return 1
    fi

    # Parse .repo and compare; mismatch → error
    local _recorded
    _recorded=$(< "${_path}/.repo")
    local _recorded_repo="${_recorded%%@*}"

    if [[ "${_recorded_repo}" != "${_repo}" ]]; then
      echo "::error::check-existing: repo conflict: expected '${_repo}', found '${_recorded_repo}'" >&2
      return 1
    fi

    echo "skip=true" >> "${GITHUB_OUTPUT}"
    return 0
  fi

  # 6. Path didn't exist → new checkout
  echo "skip=false" >> "${GITHUB_OUTPUT}"
  return 0
}
