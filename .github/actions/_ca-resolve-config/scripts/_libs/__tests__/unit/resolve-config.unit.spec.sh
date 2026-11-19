#!/usr/bin/env bash
# src: .github/actions/_ca-resolve-config/scripts/_libs/__tests__/unit/resolve-config.unit.spec.sh
# @(#) : unit tests for resolve-config.lib.sh
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for resolve-config.lib.sh
# Module: composite-action/resolve-config (test_scope RC)
# Target: _ca-resolve-config/scripts/_libs/resolve-config.lib.sh

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
Include "${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-config/scripts/_libs/resolve-config.lib.sh"

# --- 内部ヘルパー ---
# 定数
# Path of resolve-config.lib.sh, sourced in a fresh bash process; used by T-RC-RC-0305
_RLG_LIB_PATH="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_ca-resolve-config/scripts/_libs/resolve-config.lib.sh"

# 関数
# Create an empty file (and its parent directories) at <path>
_fx_touch() {
  mkdir -p "$(dirname -- "$1")" && : >"$1"
}

# Per-example fixture: ROOT holds WS (GITHUB_WORKSPACE) and OUT (outside WS)
_fx_setup() {
  ROOT="$(mktemp -d)"
  WS="${ROOT}/ws"
  OUT="${ROOT}/out"
  mkdir -p "$WS" "$OUT"
  export GITHUB_WORKSPACE="$WS"
}

_fx_cleanup() {
  rm -rf "$ROOT"
  unset ROOT WS OUT
}

# --- テスト本体 ---
# T-RC-RC-0101 .. T-RC-RC-0105 : normal
# T-RC-RC-0201 .. T-RC-RC-0207 : error
# T-RC-RC-0301 .. T-RC-RC-0305 : edge
Describe 'resolve-config.lib.sh'
  Describe 'resolve_config()'
    BeforeEach '_fx_setup'
    AfterEach '_fx_cleanup'

    Context 'When: 正常系'
      It '[Normal] T-RC-RC-0101: config (相対) が存在すれば source=input'
        _fx_touch "${WS}/cfg/a.yml"
        When call resolve_config "cfg/a.yml" "" ""
        The status should equal 0
        The stdout should equal "${WS}/cfg/a.yml input"
      End
      It '[Normal] T-RC-RC-0102: config (workspace 内の絶対パス) が存在すれば source=input'
        _fx_touch "${WS}/cfg/a.yml"
        When call resolve_config "${WS}/cfg/a.yml" "" ""
        The status should equal 0
        The stdout should equal "${WS}/cfg/a.yml input"
      End
      It '[Normal] T-RC-RC-0103: local のみ存在すれば source=local'
        _fx_touch "${WS}/.cfg/local.yml"
        When call resolve_config "" ".cfg/local.yml" ".cfg/global.yml"
        The status should equal 0
        The stdout should equal "${WS}/.cfg/local.yml local"
      End
      It '[Normal] T-RC-RC-0104: global のみ存在すれば source=global'
        _fx_touch "${WS}/.cfg/global.yml"
        When call resolve_config "" ".cfg/local.yml" ".cfg/global.yml"
        The status should equal 0
        The stdout should equal "${WS}/.cfg/global.yml global"
      End
      It '[Normal] T-RC-RC-0105: local と global が両方存在すれば local を優先する'
        _fx_touch "${WS}/.cfg/local.yml"
        _fx_touch "${WS}/.cfg/global.yml"
        When call resolve_config "" ".cfg/local.yml" ".cfg/global.yml"
        The status should equal 0
        The stdout should equal "${WS}/.cfg/local.yml local"
      End
    End

    Context 'When: 異常系'
      It '[Error] T-RC-RC-0201: config が不在なら local が存在してもフォールバックしない'
        _fx_touch "${WS}/local.yml"
        When call resolve_config "missing.yml" "local.yml" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*missing.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0202: 3 つとも不在ならエラー'
        When call resolve_config "" "local.yml" "global.yml"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0203: config が .. で workspace 外 (実在) ならエラー'
        _fx_touch "${ROOT}/outside.yml"
        When call resolve_config "../outside.yml" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0204: config が workspace 外の絶対パス (実在) ならエラー'
        _fx_touch "${OUT}/x.yml"
        When call resolve_config "${OUT}/x.yml" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0205: local_config が .. で workspace 外ならエラー'
        _fx_touch "${ROOT}/outside.yml"
        When call resolve_config "" "../outside.yml" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0206: global_config が .. で workspace 外ならエラー'
        _fx_touch "${ROOT}/outside.yml"
        When call resolve_config "" "" "../outside.yml"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Error] T-RC-RC-0207: GITHUB_WORKSPACE 未設定ならエラー'
        unset GITHUB_WORKSPACE
        When call resolve_config "a.yml" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::GITHUB_WORKSPACE*"
        The lines of stderr should equal 1
      End
    End

    Context 'When: エッジケース'
      It '[Edge] T-RC-RC-0301: config がディレクトリならエラー'
        mkdir -p "${WS}/cfg"
        When call resolve_config "cfg" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Edge] T-RC-RC-0302: 3 引数がすべて空ならエラー'
        When call resolve_config "" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Edge] T-RC-RC-0303: workspace 内で完結する .. を含むパスも拒否する'
        _fx_touch "${WS}/a.yml"
        mkdir -p "${WS}/cfg"
        When call resolve_config "cfg/../a.yml" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The lines of stderr should equal 1
      End
      It '[Edge] T-RC-RC-0304: コマンド置換文字列を評価しない'
        _cmd="\$(touch \"${WS}/pwned\")"
        When call resolve_config "$_cmd" "" ""
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::*"
        The path "${WS}/pwned" should not be exist
      End
      It '[Edge] T-RC-RC-0305: ロードガードにより 2 回目の source は何も再定義しない'
        # $1 and $? are expanded by the inner bash, not by this shell
        # shellcheck disable=SC2016
        When run bash -c 'unset RESOLVE_CONFIG_LIB_LOADED; . "$1"; resolve_config() { echo sentinel; }; . "$1"; echo "rc=$? loaded=$RESOLVE_CONFIG_LIB_LOADED"; resolve_config' _ "$_RLG_LIB_PATH"
        The status should equal 0
        The stdout should equal "rc=0 loaded=1
sentinel"
        The stderr should equal ""
      End
    End
  End
End
