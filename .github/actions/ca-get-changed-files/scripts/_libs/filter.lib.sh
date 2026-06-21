#!/usr/bin/env bash
# src: .github/actions/ca-get-changed-files/scripts/_libs/filter.lib.sh
# @(#) : SHA解決とGITHUB_OUTPUT書き出しユーティリティ
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

[ -n "${FILTER_LIB_LOADED:-}" ] && return 0
FILTER_LIB_LOADED=1

resolve_before_sha() {
  local _sha="${1:-}"
  local _empty_tree="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
  if [[ -z "$_sha" ]] || [[ "$_sha" =~ ^0{40}$ ]]; then
    echo "$_empty_tree"
  else
    echo "$_sha"
  fi
}

write_multiline_output() {
  local _key="$1"
  local _value="$2"
  printf '%s<<EOF\n%s\nEOF\n' "$_key" "$_value" >> "${GITHUB_OUTPUT:-/dev/null}"
}
