#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Architecture Unit'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # OS Detection Tests
  # ============================================================================

  Describe 'detect_os()'
    Context 'with Linux argument'
      It 'returns normalized os name'
        When call detect_os "Linux"
        The status should be success
        The output should eq "linux"
      End
    End

    Context 'with Darwin argument'
      It 'returns normalized os name'
        When call detect_os "Darwin"
        The status should be success
        The output should eq "darwin"
      End
    End

    Context 'with uppercase LINUX argument'
      It 'normalizes to lowercase'
        When call detect_os "LINUX"
        The status should be success
        The output should eq "linux"
      End
    End
  End

  # ============================================================================
  # Architecture Detection Tests
  # ============================================================================

  Describe 'detect_architecture()'
    Context 'with x86_64 argument'
      It 'returns x86_64'
        When call detect_architecture "x86_64"
        The status should be success
        The output should eq "x86_64"
      End
    End

    Context 'with aarch64 argument'
      It 'returns aarch64'
        When call detect_architecture "aarch64"
        The status should be success
        The output should eq "aarch64"
      End
    End
  End

  # ============================================================================
  # OS Validation Tests
  # ============================================================================

  Describe 'validate_os()'
    Context 'with Linux OS'
      It 'returns success for Linux OS'
        When call validate_os "linux"
        The status should be success
        The output should eq "SUCCESS:Operating system is Linux"
      End
    End

    Context 'with non-Linux OS'
      It 'returns failure for Darwin (macOS)'
        When call validate_os "darwin"
        The status should be failure
        The output should eq "ERROR:Unsupported OS: darwin (Linux required)"
      End

      It 'returns failure for Windows'
        When call validate_os "mingw64_nt-10.0-19045"
        The status should be failure
        The output should eq "ERROR:Unsupported OS: mingw64_nt-10.0-19045 (Linux required)"
      End

      It 'returns failure for FreeBSD'
        When call validate_os "freebsd"
        The status should be failure
        The output should eq "ERROR:Unsupported OS: freebsd (Linux required)"
      End

      It 'returns failure with empty OS value'
        When call validate_os ""
        The status should be failure
        The output should eq "ERROR:Unsupported OS:  (Linux required)"
      End
    End
  End
End
