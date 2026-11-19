#!/usr/bin/env bash
# src: .github/actions/ca-setup-tool/scripts/_libs/arch.lib.sh
# @(#) : Provide detect_arch() function for mapping RUNNER_ARCH to arch strings
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

[ -n "${ARCH_LIB_LOADED:-}" ] && return 0
ARCH_LIB_LOADED=1

detect_arch() {
  local _runner_arch="${RUNNER_ARCH:-}"
  if [ -z "$_runner_arch" ]; then
    echo "::error::RUNNER_ARCH is not set" >&2
    return 1
  fi

  case "$_runner_arch" in
    X64)
      echo "amd64"
      echo "x64"
      ;;
    ARM64)
      echo "arm64"
      ;;
    *)
      echo "::error::Unsupported RUNNER_ARCH: ${_runner_arch}" >&2
      return 1
      ;;
  esac
}
