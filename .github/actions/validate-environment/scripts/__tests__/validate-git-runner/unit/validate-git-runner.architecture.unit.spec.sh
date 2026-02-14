#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Architecture Validation'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  # Source the script
  Include "$SCRIPT_PATH"

  # ============================================================================
  # OS Detection Tests
  # ============================================================================

  Describe 'detect_os()'
    Context 'with mocked Linux environment'
      uname() {
        if [ "$1" = "-s" ]; then
          echo "Linux"
        else
          command uname "$@"
        fi
      }

      It 'returns normalized os name'
        When call detect_os
        The status should be success
        The output should eq "linux"
      End
    End

    Context 'with mocked Darwin environment'
      uname() {
        if [ "$1" = "-s" ]; then
          echo "Darwin"
        else
          command uname "$@"
        fi
      }

      It 'returns normalized os name'
        When call detect_os
        The status should be success
        The output should eq "darwin"
      End
    End

    Context 'with uppercase LINUX'
      uname() {
        if [ "$1" = "-s" ]; then
          echo "LINUX"
        else
          command uname "$@"
        fi
      }

      It 'normalizes to lowercase'
        When call detect_os
        The status should be success
        The output should eq "linux"
      End
    End
  End

  # ============================================================================
  # Architecture Detection Tests
  # ============================================================================

  Describe 'detect_architecture()'
    Context 'with real system architecture'
      It 'returns architecture name'
        When call detect_architecture
        The status should be success
        The output should match pattern "x86_64|aarch64|arm64|amd64"
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

  # ============================================================================
  # Architecture Normalization Tests
  # ============================================================================

  Describe 'normalize_architecture()'
    Context 'amd64 variants'
      It 'normalizes x86_64 to amd64'
        When call normalize_architecture "x86_64"
        The status should be success
        The output should eq "amd64"
      End

      It 'normalizes amd64 to amd64 (idempotent)'
        When call normalize_architecture "amd64"
        The status should be success
        The output should eq "amd64"
      End

      It 'normalizes x64 to amd64'
        When call normalize_architecture "x64"
        The status should be success
        The output should eq "amd64"
      End
    End

    Context 'arm64 variants'
      It 'normalizes aarch64 to arm64'
        When call normalize_architecture "aarch64"
        The status should be success
        The output should eq "arm64"
      End

      It 'normalizes arm64 to arm64 (idempotent)'
        When call normalize_architecture "arm64"
        The status should be success
        The output should eq "arm64"
      End
    End

    Context 'unsupported architectures'
      It 'returns failure for mips'
        When call normalize_architecture "mips"
        The status should be failure
      End

      It 'returns failure for riscv'
        When call normalize_architecture "riscv"
        The status should be failure
      End
    End
  End

  # ============================================================================
  # Architecture Validation Tests
  # ============================================================================

  Describe 'validate_expected_arch()'
    BeforeEach 'setup_expected_arch'
    AfterEach 'cleanup_expected_arch'

    setup_expected_arch() {
      EXPECTED_ARCH=""
    }

    cleanup_expected_arch() {
      unset EXPECTED_ARCH
    }

    Context 'valid expected architectures'
      It 'accepts amd64'
        EXPECTED_ARCH="amd64"
        When call validate_expected_arch
        The status should be success
      End

      It 'accepts arm64'
        EXPECTED_ARCH="arm64"
        When call validate_expected_arch
        The status should be success
      End
    End

    Context 'invalid expected architectures'
      It 'rejects x86_64 (not canonical)'
        EXPECTED_ARCH="x86_64"
        When call validate_expected_arch
        The status should be failure
      End

      It 'rejects mips'
        EXPECTED_ARCH="mips"
        When call validate_expected_arch
        The status should be failure
      End

      It 'rejects empty value'
        EXPECTED_ARCH=""
        When call validate_expected_arch
        The status should be failure
      End
    End
  End

  Describe 'validate_detected_arch()'
    Context 'with valid architectures'
      It 'validates x86_64 architecture'
        When call validate_detected_arch "x86_64"
        The status should be success
      End

      It 'validates aarch64 architecture'
        When call validate_detected_arch "aarch64"
        The status should be success
      End

      It 'validates amd64 architecture'
        When call validate_detected_arch "amd64"
        The status should be success
      End

      It 'validates arm64 architecture'
        When call validate_detected_arch "arm64"
        The status should be success
      End
    End

    Context 'with invalid architectures'
      It 'rejects unsupported architecture'
        When call validate_detected_arch "mips"
        The status should be failure
      End

      It 'rejects riscv architecture'
        When call validate_detected_arch "riscv"
        The status should be failure
      End
    End
  End

  Describe 'validate_arch_match()'
    BeforeEach 'setup_arch_match'
    AfterEach 'cleanup_arch_match'

    setup_arch_match() {
      EXPECTED_ARCH=""
      NORMALIZED_ARCH=""
    }

    cleanup_arch_match() {
      unset EXPECTED_ARCH NORMALIZED_ARCH
    }

    Context 'matching architectures'
      It 'returns success when both are amd64'
        EXPECTED_ARCH="amd64"
        NORMALIZED_ARCH="amd64"
        When call validate_arch_match
        The status should be success
      End

      It 'returns success when both are arm64'
        EXPECTED_ARCH="arm64"
        NORMALIZED_ARCH="arm64"
        When call validate_arch_match
        The status should be success
      End
    End

    Context 'mismatching architectures'
      It 'returns failure when amd64 vs arm64'
        EXPECTED_ARCH="amd64"
        NORMALIZED_ARCH="arm64"
        When call validate_arch_match
        The status should be failure
      End

      It 'returns failure when arm64 vs amd64'
        EXPECTED_ARCH="arm64"
        NORMALIZED_ARCH="amd64"
        When call validate_arch_match
        The status should be failure
      End
    End
  End
End
