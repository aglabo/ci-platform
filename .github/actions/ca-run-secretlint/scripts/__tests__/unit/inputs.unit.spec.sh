#!/usr/bin/env bash
# src: .github/actions/ca-run-secretlint/scripts/__tests__/unit/inputs.unit.spec.sh
# @(#) : ShellSpec unit tests for validate_secretlint_version()
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT
# shellcheck shell=bash

Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/error.lib.sh"
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/ca-run-secretlint/scripts/_libs/inputs.lib.sh"

Describe 'T-RSL-VER: validate_secretlint_version'
  # Accepted: strictly X.Y.Z, no output
  Describe 'accepted versions'
    Parameters
      "T-RSL-VER-01" "14.0.0"
      "T-RSL-VER-08" "14.10.100"
      "T-RSL-VER-10" "14.0.1"
      "T-RSL-VER-11" "15.0.0"
      "T-RSL-VER-12" "100.0.0"
    End

    It "[Normal] $1: accepts $2"
      When call validate_secretlint_version "$2"
      The status should be success
      The stderr should equal ""
    End
  End

  # Rejected: anything but X.Y.Z, with an ::error:: annotation
  Describe 'rejected versions'
    Parameters
      "T-RSL-VER-02" "14.0"
      "T-RSL-VER-03" "v14.0.0"
      "T-RSL-VER-04" ""
      "T-RSL-VER-05" "latest"
      "T-RSL-VER-06" "14.0.0; id"
      "T-RSL-VER-07" "14.0.0-beta.1"
      "T-RSL-VER-09" $'14.0.0\n15.0.0'
      "T-RSL-VER-13" "13.9.9"
      "T-RSL-VER-14" "13.0.0"
      "T-RSL-VER-15" "0.0.0"
      "T-RSL-VER-16" "9.9.9"
      "T-RSL-VER-17" "014.0.0"
      "T-RSL-VER-18" "00.1.2"
    End

    It "[Error] $1: rejects '$2'"
      When call validate_secretlint_version "$2"
      The status should be failure
      The stderr should start with "::error::secretlint-version:"
    End
  End

  # Error message names the format and the minimum major
  Describe 'error message'
    It "[Error] T-RSL-VER-19: names X.Y.Z and the minimum major"
      When call validate_secretlint_version "13.9.9"
      The status should be failure
      The stderr should include "X.Y.Z"
      The stderr should include "major"
      The stderr should include "14 or later"
    End
  End
End
