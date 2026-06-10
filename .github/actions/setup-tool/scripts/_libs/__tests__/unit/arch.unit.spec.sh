#!/usr/bin/env bash
# src: .github/actions/setup-tool/scripts/_libs/__tests__/unit/arch.unit.spec.sh
# @(#) : ShellSpec unit tests for detect_arch()
# Copyright (c) 2026- atsushifx <atsushifx@gmail.com>
# MIT License
# shellcheck shell=bash

LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/setup-tool/scripts/_libs/arch.lib.sh"
Include "$LIB_PATH"

# ─── Internal Helpers

cleanup_arch() { unset RUNNER_ARCH; }

# ─── Tests

Describe 'Given: RUNNER_ARCH is X64'
  BeforeEach 'setup_x64'
  AfterEach 'cleanup_arch'

  setup_x64() {
    # shellcheck disable=SC2034
    RUNNER_ARCH="X64"
  }

  Describe 'When: detect_arch is called'
    Describe 'Then: Task T-06-01 - Normal Cases'
      It "T-06-01-01: outputs amd64 and x64"
        When call detect_arch
        The output line 1 should equal "amd64"
        The output line 2 should equal "x64"
      End
    End
  End
End

Describe 'Given: RUNNER_ARCH is ARM64'
  BeforeEach 'setup_arm64'
  AfterEach 'cleanup_arch'

  setup_arm64() {
    # shellcheck disable=SC2034
    RUNNER_ARCH="ARM64"
  }

  Describe 'When: detect_arch is called'
    Describe 'Then: Task T-06-02 - Normal Cases'
      It "T-06-02-01: outputs arm64 only"
        When call detect_arch
        The output line 1 should equal "arm64"
        The lines of output should equal 1
      End
    End
  End
End

Describe 'Given: RUNNER_ARCH is unsupported or unset'
  AfterEach 'cleanup_arch'

  Describe 'When: detect_arch is called with RUNNER_ARCH=MIPS'
    BeforeEach 'setup_mips'

    setup_mips() {
      # shellcheck disable=SC2034
      RUNNER_ARCH="MIPS"
    }

    Describe 'Then: Task T-06-03 - Error Cases'
      It "T-06-03-01: outputs ::error:: to stderr and returns 1"
        When call detect_arch
        The status should eq 1
        The error should include "::error::"
      End
    End
  End

  Describe 'When: detect_arch is called with RUNNER_ARCH empty'
    BeforeEach 'setup_empty'

    setup_empty() {
      # shellcheck disable=SC2034
      RUNNER_ARCH=""
    }

    Describe 'Then: Task T-06-03 - Error Cases'
      It "T-06-03-02: outputs ::error:: to stderr and returns 1 when RUNNER_ARCH is empty"
        When call detect_arch
        The status should eq 1
        The error should include "::error::"
      End
    End
  End
End
