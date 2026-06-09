#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/_libs/__tests__/unit/dirs.unit.spec.sh
# @(#) : ShellSpec unit tests for setup_dirs()
#
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License

# shellcheck shell=bash

LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/dirs.lib.sh"
Include "$LIB_PATH"

Describe 'Given: RUNNER_TEMP is set'
  _runner_temp=""
  _github_env=""
  _github_path=""

  BeforeEach 'setup_normal'
  AfterEach 'cleanup_normal'

  setup_normal() {
    _runner_temp=$(mktemp -d)
    _github_env=$(mktemp)
    _github_path=$(mktemp)
    # shellcheck disable=SC2034
    RUNNER_TEMP="$_runner_temp"
    # shellcheck disable=SC2034
    GITHUB_ENV="$_github_env"
    # shellcheck disable=SC2034
    GITHUB_PATH="$_github_path"
    # shellcheck disable=SC2034
    BIN_DIR=""
    TEMP_DIR=""
  }

  cleanup_normal() {
    [ -n "$_runner_temp" ] && rm -rf "$_runner_temp"
    [ -n "${TEMP_DIR:-}" ] && rm -rf "$TEMP_DIR"
    [ -n "$_github_env" ] && rm -f "$_github_env"
    [ -n "$_github_path" ] && rm -f "$_github_path"
  }

  Describe 'When: setup_dirs is called'
    Describe 'Then: Task T-dir-nor - Normal Cases'
      It "T-dir-nor-01: creates BIN_DIR as \${RUNNER_TEMP}/bin"
        When call setup_dirs
        The status should be success
        The directory "${_runner_temp}/bin" should be exist
      End

      It 'T-dir-nor-02: sets TEMP_DIR to a non-empty path and creates the directory'
        When call setup_dirs
        The status should be success
        The variable TEMP_DIR should not be blank
      End

      It 'T-dir-nor-03: appends BIN_DIR path to GITHUB_PATH file'
        When call setup_dirs
        The status should be success
        The contents of file "${_github_path}" should include "${_runner_temp}/bin"
      End

      It 'T-dir-nor-04: appends BIN_DIR= and TEMP_DIR= lines to GITHUB_ENV file'
        When call setup_dirs
        The status should be success
        The contents of file "${_github_env}" should include "BIN_DIR="
        The contents of file "${_github_env}" should include "TEMP_DIR="
      End
    End
  End
End

Describe 'Given: RUNNER_TEMP is unset'
  BeforeEach 'setup_no_runner_temp'
  AfterEach 'cleanup_no_runner_temp'

  setup_no_runner_temp() {
    unset RUNNER_TEMP
  }

  cleanup_no_runner_temp() {
    :
  }

  Describe 'When: setup_dirs is called'
    Describe 'Then: Task T-dir-err - Error Cases'
      It 'T-dir-err-01: outputs ::error:: to stderr and returns 1'
        When call setup_dirs
        The status should eq 1
        The error should include "::error::"
      End
    End
  End
End

Describe 'Given: RUNNER_TEMP is set but GITHUB_ENV and GITHUB_PATH are unset'
  _runner_temp_edge=""

  BeforeEach 'setup_edge'
  AfterEach 'cleanup_edge'

  setup_edge() {
    _runner_temp_edge=$(mktemp -d)
    # shellcheck disable=SC2034
    RUNNER_TEMP="$_runner_temp_edge"
    unset GITHUB_ENV
    unset GITHUB_PATH
    # shellcheck disable=SC2034
    BIN_DIR=""
    TEMP_DIR=""
  }

  cleanup_edge() {
    [ -n "$_runner_temp_edge" ] && rm -rf "$_runner_temp_edge"
    [ -n "${TEMP_DIR:-}" ] && rm -rf "$TEMP_DIR"
  }

  Describe 'When: setup_dirs is called'
    Describe 'Then: Task T-dir-edg - Edge Cases'
      It 'T-dir-edg-01: creates BIN_DIR and TEMP_DIR, exits 0'
        When call setup_dirs
        The status should be success
        The directory "${_runner_temp_edge}/bin" should be exist
        The variable TEMP_DIR should not be blank
      End
    End
  End
End
