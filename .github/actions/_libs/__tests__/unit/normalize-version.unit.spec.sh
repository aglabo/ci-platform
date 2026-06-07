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
    # T-01-01-01: 小文字 v プレフィックス
    It 'returns "1.2.3" for input "v1.2.3" (lowercase v prefix)'
      When call normalize_version "v1.2.3"
      The output should equal "1.2.3"
    End

    # T-01-01-02: 大文字 V プレフィックス
    It 'returns "1.2.3" for input "V1.2.3" (uppercase V prefix)'
      When call normalize_version "V1.2.3"
      The output should equal "1.2.3"
    End

    # T-01-01-03: プレフィックスなし
    It 'returns "1.2.3" for input "1.2.3" (no prefix)'
      When call normalize_version "1.2.3"
      The output should equal "1.2.3"
    End
  End

  Context '異常系: 不正なバージョン形式'
    # T-01-02-01: X.Y.Z 形式でない
    It 'exits with status 1 for input "latest" (non-semver)'
      When call normalize_version "latest"
      The status should equal 1
      The stderr should include "Error: Invalid version format: latest"
    End

    # T-01-02-02: 空文字列
    It 'exits with status 1 for input "" (empty string)'
      When call normalize_version ""
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-03: prerelease サフィックスは不正
    It 'exits with status 1 for input "1.2.3-beta" (prerelease suffix)'
      When call normalize_version "1.2.3-beta"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-04: アルファベットを含む形式は不正
    It 'exits with status 1 for input "1.2.x" (non-numeric patch)'
      When call normalize_version "1.2.x"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-05: v のみ（数字なし）
    It 'exits with status 1 for input "v" (prefix only, no digits)'
      When call normalize_version "v"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-06: 4要素は不正（X.Y.Z.W）
    It 'exits with status 1 for input "1.2.3.4" (four components)'
      When call normalize_version "1.2.3.4"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-07: 末尾ドット
    It 'exits with status 1 for input "1.2." (trailing dot)'
      When call normalize_version "1.2."
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End

    # T-01-02-08: vv ダブルプレフィックス（v 除去後も v が残る）
    It 'exits with status 1 for input "vv1.2.3" (double v prefix)'
      When call normalize_version "vv1.2.3"
      The status should equal 1
      The stderr should include "Error: Invalid version format:"
    End
  End
End
