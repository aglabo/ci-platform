#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool-repo/scripts/_libs/verify-and-add-path.lib.sh
# @(#) : verify_and_add_path — インストール後検証とPATH追加ライブラリ
# shellcheck shell=bash

[ -n "${VERIFY_AND_ADD_PATH_LIB_LOADED:-}" ] && return 0
VERIFY_AND_ADD_PATH_LIB_LOADED=1

##
# @description Verify post-install structure and add bin/ to GITHUB_PATH.
# @arg $1 _path    — checked-out repo root
# @arg $2 _repo    — "owner/repo" format
# @arg $3 _sha     — commit SHA
# @env SKIP_REPO     — "true" or "false"
# @env REPO_LOCK_DIR — path to .repo.lock directory
# @env GITHUB_PATH   — path to github path file
# @return 0 on success, 1 on failure
verify_and_add_path() {
  local _path="$1"
  local _repo="$2"
  local _sha="$3"

  # R-015: node_modules/.bin/ must exist
  if [[ ! -d "${_path}/node_modules/.bin" ]]; then
    echo "::error::verify-and-add-path: node_modules/.bin/ not found: ${_path}/node_modules/.bin" >&2
    return 1
  fi

  # R-016: bin/ must contain at least one file
  local _has_file=false
  for _f in "${_path}/bin/"*; do
    [[ -e "${_f}" ]] || continue
    _has_file=true
    break
  done
  if [[ "${_has_file}" == false ]]; then
    echo "::error::verify-and-add-path: no files found in ${_path}/bin/" >&2
    return 1
  fi

  # R-017: all files in bin/ must have execute permission
  for _f in "${_path}/bin/"*; do
    [[ -e "${_f}" ]] || continue
    # shebang があれば実行ビットを付与（Windows では chmod が必要）
    if head -c 2 "${_f}" 2>/dev/null | grep -q '^#!'; then
      chmod +x "${_f}"
    fi
    if [[ ! -x "${_f}" ]]; then
      echo "::error::verify-and-add-path: file not executable: ${_f}" >&2
      return 1
    fi
  done

  # R-019: append bin/ to GITHUB_PATH
  echo "${_path}/bin" >> "${GITHUB_PATH}"

  # R-020 / R-020S: write .repo unless SKIP_REPO=true
  if [[ "${SKIP_REPO}" != "true" ]]; then
    printf '%s@%s' "${_repo}" "${_sha}" > "${_path}/.repo"
  fi

  # Release lock
  [[ -n "${REPO_LOCK_DIR:-}" ]] && rm -rf "${REPO_LOCK_DIR}"

  return 0
}
