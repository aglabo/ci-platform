#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/setup-tool.sh
# @(#) : Orchestrate tool download, verification, and installation
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../../_libs/version.lib.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../../_libs/validation.lib.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_libs/dirs.lib.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_libs/arch.lib.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_libs/download.lib.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_libs/install.lib.sh"

main() {
  local _repo="${1:?repo argument is required (owner/repo)}"
  local _raw_version="${2:?tool-version argument is required}"

  validate_repo "$_repo" || return $?

  local _version
  _version=$(normalize_version "$_raw_version") || return $?

  validate_version "$_version" || return $?

  local _tool_name="${_repo##*/}"

  trap 'cleanup "${TEMP_DIR:-}"' EXIT

  setup_dirs || return $?

  local _arch_out
  _arch_out=$(detect_arch) || return $?
  mapfile -t _arch_candidates <<< "$_arch_out"

  local _api_url
  _api_url=$(build_url "$_repo" "$_version")

  local _assets_out
  _assets_out=$(resolve_assets "$_api_url" "$_tool_name" "${_arch_candidates[@]}") || return $?
  mapfile -t _assets <<< "$_assets_out"

  local _download_url="${_assets[0]}"
  local _checksum_url="${_assets[1]}"
  local _arch_suffix="${_assets[2]}"

  download_tool "$_download_url" "$_checksum_url" "${TEMP_DIR}" "$_tool_name" || return $?
  verify_checksum "$_tool_name" "$_version" "$_arch_suffix" "${TEMP_DIR}" || return $?
  extract_install "$_tool_name" "${TEMP_DIR}" "${BIN_DIR}" || return $?
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
