#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for normalize_version() function
# Module: common libs
# Target: _libs/version.lib.sh

Describe 'normalize_version()'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/version.lib.sh"
  Include "$LIB_PATH"

  Context '正常系: vプレフィックスを除去する'
    It 'T-nrm-nor-01: returns "1.2.3" for input "v1.2.3" (lowercase v prefix)'
      When call normalize_version "v1.2.3"
      The output should equal "1.2.3"
    End

    It 'T-nrm-nor-02: returns "1.2.3" for input "V1.2.3" (uppercase V prefix)'
      When call normalize_version "V1.2.3"
      The output should equal "1.2.3"
    End

    It 'T-nrm-nor-03: returns "1.2.3" for input "1.2.3" (no prefix)'
      When call normalize_version "1.2.3"
      The output should equal "1.2.3"
    End

    It 'T-nrm-nor-04: returns "1.7.0" for input "1.7" (X.Y format, no prefix)'
      When call normalize_version "1.7"
      The output should equal "1.7.0"
    End

    It 'T-nrm-nor-05: returns "1.7.0" for input "v1.7" (X.Y format, v prefix)'
      When call normalize_version "v1.7"
      The output should equal "1.7.0"
    End
  End

  Context '異常系: 不正なバージョン形式'
    It 'T-nrm-err-01: exits with status 1 for input "latest" (non-semver)'
      When call normalize_version "latest"
      The status should equal 1
      The stderr should include "Error: Invalid version format: latest"
    End

    It 'T-nrm-err-02: exits with status 1 for input "" (empty string)'
      When call normalize_version ""
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-03: exits with status 1 for input "1.2.3-beta" (prerelease suffix)'
      When call normalize_version "1.2.3-beta"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-04: exits with status 1 for input "1.2.x" (non-numeric patch)'
      When call normalize_version "1.2.x"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-05: exits with status 1 for input "v" (prefix only, no digits)'
      When call normalize_version "v"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-06: exits with status 1 for input "1.2.3.4" (four components)'
      When call normalize_version "1.2.3.4"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-07: exits with status 1 for input "1.2." (trailing dot)'
      When call normalize_version "1.2."
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-08: exits with status 1 for input "vv1.2.3" (double v prefix)'
      When call normalize_version "vv1.2.3"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    It 'T-nrm-err-09: exits with status 1 for input "1" (one component, not X.Y.Z)'
      When call normalize_version "1"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End
  End
End
