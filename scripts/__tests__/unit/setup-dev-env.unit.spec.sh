#!/usr/bin/env bash
# src: scripts/__tests__/unit/setup-dev-env.unit.spec.sh
# @(#) : setup-dev-env.sh source guard ユニットテスト
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

# shellcheck disable=SC1091
Include "${SHELLSPEC_PROJECT_ROOT}/scripts/setup-dev-env.sh"

# ─── Internal Helpers ───────────────────────────────────────────────────────

# Constants

# busybox ash shim that `bash` may resolve to on Windows (T-SDE-SG-01)
_BUSYBOX_BASH="/c/app/scoop/shims/bash.exe"
# Absolute path of the script under test
_SCRIPT="${SHELLSPEC_PROJECT_ROOT}/scripts/setup-dev-env.sh"
# Message main prints when it detects a CI environment (T-SDE-SG-01, 02)
_CI_SKIP_MSG="CI environment detected. Skipping dev tools install."

# Functions

##
# @description Skip condition: the busybox ash shim is not installed
# @return 0 If the shim is absent (case is skipped)
# @return 1 If the shim is executable
_no_busybox_shim() { [ ! -x "$_BUSYBOX_BASH" ]; }

##
# @description Source the script under test with CI=1 in the current shell
# @return Status of the source command (0 when the guard returns early)
# shellcheck source=scripts/setup-dev-env.sh
_source_script() { CI=1 . "$_SCRIPT"; }

# ─── Tests ──────────────────────────────────────────────────────────────────

# setup-dev-env.sh source guard: run main only on direct execution.
# Test IDs: T-SDE-SG-01 .. T-SDE-SG-04
Describe 'setup-dev-env.sh source guard'
  # Direct execution under busybox ash and Git bash reaches main
  Describe 'When: CI=1 で直接実行する'
    Describe 'Then: Task T-01-01 - インストールをスキップして exit 0'
      It '[Normal] T-SDE-SG-01: busybox ash shim で実行 -> CI スキップメッセージ, exit 0'
        Skip if "busybox shim not found" _no_busybox_shim
        When run command env CI=1 "$_BUSYBOX_BASH" "$_SCRIPT"
        The output should include "$_CI_SKIP_MSG"
        The status should equal 0
      End

      It '[Normal] T-SDE-SG-02: Git bash で実行 -> CI スキップメッセージ, exit 0'
        When run command env CI=1 "$BASH" "$_SCRIPT"
        The output should include "$_CI_SKIP_MSG"
        The status should equal 0
      End
    End
  End

  # Sourcing defines the functions but does not run main
  Describe 'When: スクリプトを source する'
    Describe 'Then: Task T-01-02 - main を実行しない'
      It '[Normal] T-SDE-SG-03: CI=1 で source -> 出力なし, status 0'
        When call _source_script
        The output should equal ""
        The status should equal 0
      End

      It '[Normal] T-SDE-SG-04: source 後 -> is_ci_environment が関数として定義済み'
        When call type -t is_ci_environment
        The output should equal "function"
      End
    End
  End
End
