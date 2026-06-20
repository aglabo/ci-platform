#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/_libs/dirs.lib.sh
# @(#) : Provide setup_dirs() function for creating BIN_DIR and TEMP_DIR
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

[ -n "${DIRS_LIB_LOADED:-}" ] && return 0
DIRS_LIB_LOADED=1

setup_dirs() {
  local _runner_temp="${RUNNER_TEMP:-}"
  if [ -z "$_runner_temp" ]; then
    echo "::error::RUNNER_TEMP is not set" >&2
    return 1
  fi

  local _bin_dir="${_runner_temp}/bin"
  mkdir -p "$_bin_dir"
  BIN_DIR="$_bin_dir"

  local _temp_dir
  _temp_dir=$(mktemp -d)
  TEMP_DIR="$_temp_dir"

  echo "BIN_DIR=${BIN_DIR}" >>"${GITHUB_ENV:-/dev/null}"
  echo "TEMP_DIR=${TEMP_DIR}" >>"${GITHUB_ENV:-/dev/null}"
  echo "${BIN_DIR}" >>"${GITHUB_PATH:-/dev/null}"
}
