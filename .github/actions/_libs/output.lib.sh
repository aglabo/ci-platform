#!/usr/bin/env bash
# src: .github/actions/_libs/output.lib.sh
# @(#) : output utility functions for composite actions
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

[ -n "${OUTPUT_LIB_LOADED:-}" ] && return 0
OUTPUT_LIB_LOADED=1

out_status() {
  echo "${GITHUB_OUTPUT:-/dev/null}"
}

write_status() {
  echo "status=$1" >>"${GITHUB_OUTPUT:-/dev/null}"
  echo "message=$2" >>"${GITHUB_OUTPUT:-/dev/null}"
}
