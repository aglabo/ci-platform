#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2329

Describe 'env.lib.sh'
  LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/env.lib.sh"
  Include "$LIB_PATH"

  Describe 'check_env_var()'
    Context '正常系: 変数存在確認のみ'
      setup() { export TEST_CHECK_VAR="some_value"; }
      cleanup() { unset TEST_CHECK_VAR; }
      Before 'setup'
      After 'cleanup'

      It '変数が存在する場合 exit 0 を返す'
        When call check_env_var 'TEST_CHECK_VAR'
        The status should equal 0
      End
    End

    Context '正常系: 変数値一致確認'
      setup() { export TEST_CHECK_VAR="expected"; }
      cleanup() { unset TEST_CHECK_VAR; }
      Before 'setup'
      After 'cleanup'

      It '値が一致する場合 exit 0 を返す'
        When call check_env_var 'TEST_CHECK_VAR' 'expected'
        The status should equal 0
      End
    End

    Context '異常系: 値不一致'
      setup() { export TEST_CHECK_VAR="actual"; }
      cleanup() { unset TEST_CHECK_VAR; }
      Before 'setup'
      After 'cleanup'

      It '値が不一致の場合 exit 1 を返す'
        When call check_env_var 'TEST_CHECK_VAR' 'different'
        The status should equal 1
      End
    End

    Context '異常系: 変数未設定'
      setup() { unset TEST_UNSET_VAR; }
      Before 'setup'

      It '変数が未設定の場合 exit 1 を返す'
        When call check_env_var 'TEST_UNSET_VAR'
        The status should equal 1
      End
    End

    Context 'エッジケース: 変数が空文字'
      setup() { export TEST_EMPTY_VAR=""; }
      cleanup() { unset TEST_EMPTY_VAR; }
      Before 'setup'
      After 'cleanup'

      It '変数が空文字の場合 exit 1 を返す'
        When call check_env_var 'TEST_EMPTY_VAR'
        The status should equal 1
      End
    End

    Context 'エッジケース: 変数がスペースのみ'
      setup() { export TEST_SPACE_VAR=" "; }
      cleanup() { unset TEST_SPACE_VAR; }
      Before 'setup'
      After 'cleanup'

      It 'スペースのみの値は非空なので exit 0 を返す'
        When call check_env_var 'TEST_SPACE_VAR'
        The status should equal 0
      End
    End

    Context 'エッジケース: expected_value に空文字を明示渡し'
      setup() { export TEST_CHECK_VAR="value"; }
      cleanup() { unset TEST_CHECK_VAR; }
      Before 'setup'
      After 'cleanup'

      It 'expected_value が空文字のとき存在確認のみで exit 0 を返す'
        When call check_env_var 'TEST_CHECK_VAR' ''
        The status should equal 0
      End
    End

    Context 'エッジケース: 数値や特殊文字を含む値の一致確認'
      setup() { export TEST_SPECIAL_VAR="github-hosted"; }
      cleanup() { unset TEST_SPECIAL_VAR; }
      Before 'setup'
      After 'cleanup'

      It '"github-hosted" と一致するとき exit 0 を返す'
        When call check_env_var 'TEST_SPECIAL_VAR' 'github-hosted'
        The status should equal 0
      End

      It '"github-hosted" と異なる値のとき exit 1 を返す'
        When call check_env_var 'TEST_SPECIAL_VAR' 'self-hosted'
        The status should equal 1
      End
    End
  End
End
