#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool-repo/scripts/_libs/verify-and-add-path.lib.sh
# @(#) : verify_and_add_path — インストール後検証とPATH追加ライブラリ
# shellcheck shell=bash

[ -n "${VERIFY_AND_ADD_PATH_LIB_LOADED:-}" ] && return 0
VERIFY_AND_ADD_PATH_LIB_LOADED=1

# @description List bin/ candidates: files with no extension or .sh extension
# @arg $1 _bin_dir — path to bin/ directory
# @stdout newline-separated file paths
_list_bin_candidates() {
  local _bin_dir="$1"
  find -L "${_bin_dir}" -maxdepth 1 -type f 2>/dev/null | grep -E '/[^./]+$|/[^/]+\.sh$'
}

# @description Filter to files that have a shebang line
# @stdin newline-separated file paths
# @stdout newline-separated file paths with shebang
_filter_shebang() {
  while IFS= read -r _f; do
    head -c 2 "${_f}" 2>/dev/null | grep -q '^#!' && echo "${_f}"
  done
}

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

  # R-016: bin/ must contain at least one candidate (no extension or .sh)
  local _candidates
  _candidates=$(_list_bin_candidates "${_path}/bin")
  if [[ -z "${_candidates}" ]]; then
    echo "::error::verify-and-add-path: no executable candidates found in ${_path}/bin/" >&2
    return 1
  fi

  # R-017: chmod +x all shebang files, then verify execute permission
  local _shebang_files
  _shebang_files=$(echo "${_candidates}" | _filter_shebang)
  if [[ -n "${_shebang_files}" ]]; then
    while IFS= read -r _f; do
      chmod +x "${_f}"
    done <<< "${_shebang_files}"
  fi

  local _failed=false
  while IFS= read -r _f; do
    if [[ ! -x "${_f}" ]]; then
      echo "::error::verify-and-add-path: file not executable: ${_f}" >&2
      _failed=true
    fi
  done <<< "${_candidates}"
  [[ "${_failed}" == true ]] && return 1

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
