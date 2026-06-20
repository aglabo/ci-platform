#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/_libs/download.lib.sh
# @(#) : Provide build_url(), _fetch_assets(), _find_download_url(), _find_checksum_url(), resolve_assets(), and download_tool() functions for GitHub release asset resolution
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

[ -n "${DOWNLOAD_LIB_LOADED:-}" ] && return 0
DOWNLOAD_LIB_LOADED=1

build_url() {
  local _repo="$1"
  local _version="${2#v}"
  echo "https://api.github.com/repos/${_repo}/releases/tags/v${_version}"
}

_fetch_assets() {
  local _api_url="$1"
  local _raw _http_status _body
  if ! _raw=$(curl -sSL -w '\n%{http_code}' "$_api_url"); then
    echo "::error::Failed to fetch release assets from ${_api_url}" >&2
    return 2
  fi
  _http_status=$(tail -1 <<< "$_raw")
  _body=$(head -n -1 <<< "$_raw")
  if [[ "$_http_status" != "200" ]]; then
    echo "::error::Release not found (HTTP ${_http_status}) for ${_api_url}" >&2
    return 2
  fi
  echo "$_body" | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"' | tr -d '\r'
}

_find_download_url() {
  local _pairs="$1"
  shift
  local -a _arch_candidates=("$@")
  local _download_url="" _arch_suffix=""
  local arch
  for arch in "${_arch_candidates[@]}"; do
    while IFS=$'\t' read -r _name _url; do
      if [[ "$_name" == *"_linux_${arch}.tar.gz" ]]; then
        _download_url="$_url"
        _arch_suffix="$arch"
        break 2
      fi
    done <<< "$_pairs"
  done
  if [ -z "$_download_url" ]; then
    echo "::error::No matching asset found for arch candidates: ${_arch_candidates[*]}" >&2
    return 2
  fi
  echo "$_download_url"
  echo "$_arch_suffix"
}

_find_checksum_url() {
  local _pairs="$1"
  local _checksum_url=""
  while IFS=$'\t' read -r _name _url; do
    if [[ "$_name" == "checksums.txt" ]]; then
      _checksum_url="$_url"; break
    fi
  done <<< "$_pairs"
  if [ -z "$_checksum_url" ]; then
    while IFS=$'\t' read -r _name _url; do
      if [[ "$_name" == *"_checksums.txt" ]]; then
        _checksum_url="$_url"; break
      fi
    done <<< "$_pairs"
  fi
  if [ -z "$_checksum_url" ]; then
    echo "::error::No checksums file found in release assets" >&2
    return 2
  fi
  echo "$_checksum_url"
}

resolve_assets() {
  local _api_url="$1"
  local _tool_name="$2"
  shift 2
  local -a _arch_candidates=("$@")

  local _pairs
  _pairs=$(_fetch_assets "$_api_url") || return $?

  local _dl_out
  _dl_out=$(_find_download_url "$_pairs" "${_arch_candidates[@]}") || return $?
  local _download_url _arch_suffix
  _download_url=$(echo "$_dl_out" | head -1)
  _arch_suffix=$(echo "$_dl_out" | tail -1)

  local _checksum_url
  _checksum_url=$(_find_checksum_url "$_pairs") || return $?

  echo "$_download_url"
  echo "$_checksum_url"
  echo "$_arch_suffix"
}

download_tool() {
  local _download_url="$1"
  local _checksum_url="$2"
  local _temp_dir="$3"
  local _tool_name="$4"

  if ! curl -sSL -o "${_temp_dir}/${_tool_name}.tar.gz" "$_download_url"; then
    echo "::error::Failed to download ${_tool_name} from ${_download_url}" >&2
    return 2
  fi

  if ! curl -sSL -o "${_temp_dir}/checksums.txt" "$_checksum_url"; then
    echo "::error::Failed to download checksums from ${_checksum_url}" >&2
    return 2
  fi
}

verify_checksum() {
  local _tool_name="$1"
  local _tool_version="$2"
  local _arch_suffix="$3"
  local _temp_dir="$4"

  local _original_name="${_tool_name}_${_tool_version}_linux_${_arch_suffix}.tar.gz"
  local _renamed_file="${_temp_dir}/${_tool_name}.tar.gz"
  local _checksums_file="${_temp_dir}/checksums.txt"

  local _expected_hash
  _expected_hash=$(awk -v f="${_original_name}" '$2 == f {print $1}' "$_checksums_file")
  if [ -z "$_expected_hash" ]; then
    echo "::error::No checksum entry found for ${_original_name}" >&2
    return 3
  fi

  local _actual_hash
  _actual_hash=$(sha256sum "$_renamed_file" | awk '{print $1}')

  if [ "$_expected_hash" != "$_actual_hash" ]; then
    echo "::error::Checksum mismatch for ${_tool_name}: expected ${_expected_hash}, got ${_actual_hash}" >&2
    return 3
  fi
}
