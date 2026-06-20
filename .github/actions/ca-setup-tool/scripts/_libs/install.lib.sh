#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/_libs/install.lib.sh
# @(#) : Provide extract_install() function for extracting and installing tool binaries
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

[ -n "${INSTALL_LIB_LOADED:-}" ] && return 0
INSTALL_LIB_LOADED=1

extract_install() {
  local _tool_name="$1"
  local _temp_dir="$2"
  local _bin_dir="$3"

  if ! tar -xzf "${_temp_dir}/${_tool_name}.tar.gz" -C "${_temp_dir}"; then
    echo "::error::Failed to extract ${_tool_name}.tar.gz" >&2
    return 4
  fi

  if [ ! -f "${_temp_dir}/${_tool_name}" ]; then
    echo "::error::Binary ${_tool_name} not found in archive" >&2
    return 4
  fi

  install -m 755 "${_temp_dir}/${_tool_name}" "${_bin_dir}/${_tool_name}"
}

cleanup() {
  local _temp_dir="$1"
  rm -rf "$_temp_dir"
  echo "✓ Cleanup completed"
}
