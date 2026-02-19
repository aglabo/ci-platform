#!/usr/bin/env bash
#shellcheck shell=sh

Describe 'validate-git-runner.sh - Architecture Functional'
  SCRIPT_DIR="${SHELLSPEC_PROJECT_ROOT}/.github/actions/validate-environment/scripts"
  SCRIPT_PATH="${SCRIPT_DIR}/validate-git-runner.sh"

  # Source the script
  Include "$SCRIPT_PATH"

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

      It 'returns failure for empty string'
        When call normalize_architecture ""
        The status should be failure
      End

      It 'returns failure for 32bit arm'
        When call normalize_architecture "arm"
        The status should be failure
      End

      It 'returns failure for 32bit i686'
        When call normalize_architecture "i686"
        The status should be failure
      End

      It 'returns failure for uppercase X86_64 (case-sensitive)'
        When call normalize_architecture "X86_64"
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

      It 'rejects aarch64 (raw value before normalization)'
        EXPECTED_ARCH="aarch64"
        When call validate_expected_arch
        The status should be failure
      End

      It 'rejects x64 (alias not accepted)'
        EXPECTED_ARCH="x64"
        When call validate_expected_arch
        The status should be failure
      End
    End
  End

  Describe 'is_supported_architecture()'
    Context 'with valid architectures'
      It 'validates x86_64 architecture'
        When call is_supported_architecture "x86_64"
        The status should be success
      End

      It 'validates aarch64 architecture'
        When call is_supported_architecture "aarch64"
        The status should be success
      End

      It 'validates amd64 architecture'
        When call is_supported_architecture "amd64"
        The status should be success
      End

      It 'validates arm64 architecture'
        When call is_supported_architecture "arm64"
        The status should be success
      End
    End

    Context 'with invalid architectures'
      It 'rejects unsupported architecture'
        When call is_supported_architecture "mips"
        The status should be failure
      End

      It 'rejects riscv architecture'
        When call is_supported_architecture "riscv"
        The status should be failure
      End

      It 'rejects empty string'
        When call is_supported_architecture ""
        The status should be failure
      End

      It 'rejects 32bit arm'
        When call is_supported_architecture "arm"
        The status should be failure
      End

      It 'rejects 32bit i686'
        When call is_supported_architecture "i686"
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

    Context 'edge cases with empty values'
      It 'returns success when both EXPECTED_ARCH and NORMALIZED_ARCH are empty'
        When call validate_arch_match
        The status should be success
      End

      It 'returns failure when EXPECTED_ARCH is empty but NORMALIZED_ARCH is amd64'
        NORMALIZED_ARCH="amd64"
        When call validate_arch_match
        The status should be failure
      End
    End
  End
End
