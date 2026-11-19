#!/usr/bin/env bash
# src: .github/actions/_libs/__tests__/unit/path.unit.spec.sh
# @(#) : unit tests for path.lib.sh (validate_path)
#
# Copyright (c) 2026- atsushifx <https://github.com/atsushifx>
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

# Test suite for path.lib.sh
# Module: common libs (test_scope PA, target VP)
# Target: _libs/path.lib.sh
# Guard:  PATH_LIB_LOADED

# --- テスト基盤 ---
# (ShellSpec DSL: Describe / Context / It / When / The)

# --- テスト対象 ---
PATH_LIB="${SHELLSPEC_PROJECT_ROOT}/.github/actions/_libs/path.lib.sh"
Include "$PATH_LIB"

# --- 内部ヘルパー ---
# 関数
# Create an empty file (and its parent directories) at <path>
_fx_touch() {
  mkdir -p "$(dirname -- "$1")" && : >"$1"
}

# Per-example fixture: ROOT holds WS (the root passed to validate_path) and OUT (outside WS)
_fx_setup() {
  ROOT="$(mktemp -d)"
  WS="${ROOT}/ws"
  OUT="${ROOT}/out"
  mkdir -p "$WS" "$OUT"
}

_fx_cleanup() {
  rm -rf "$ROOT"
  unset ROOT WS OUT
}

# Source path.lib.sh twice in a fresh bash process and report the guard and function state
_source_twice() {
  bash -c '
    . "$1" && . "$1" || exit 1
    declare -F validate_path > /dev/null && echo "loaded=${PATH_LIB_LOADED:-} defined"
  ' _ "$PATH_LIB"
}

# Run validate_path under "set -e" in a fresh bash process
# @arg $1 value, $2 root
_validate_under_set_e() {
  bash -c 'set -e; . "$1"; validate_path target "$2" "$3"' _ "$PATH_LIB" "$1" "$2"
}

# --- テスト本体 ---
# T-PA-VP-0101 .. : normal
Describe 'path.lib.sh'
  Describe 'validate_path()'
    BeforeEach '_fx_setup'
    AfterEach '_fx_cleanup'

    Context 'When: 正常系'
      It '[Normal] T-PA-VP-0101: 相対 path は root 起点で絶対化する'
        _fx_touch "${WS}/cfg/a.yml"
        When call validate_path target "cfg/a.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/cfg/a.yml"
      End
      It '[Normal] T-PA-VP-0102: root 内の絶対 path はそのまま返す'
        _fx_touch "${WS}/cfg/a.yml"
        When call validate_path target "${WS}/cfg/a.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/cfg/a.yml"
      End
      It '[Normal] T-PA-VP-0103: root 内ファイルへの symlink は未解決の path を返す'
        _fx_touch "${WS}/real/a.yml"
        ln -s "${WS}/real/a.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/link.yml"
      End
      It '[Normal] T-PA-VP-0104: root 自体が symlink でも root 内の path を返す'
        mkdir -p "${ROOT}/real-ws"
        _fx_touch "${ROOT}/real-ws/cfg/a.yml"
        ln -s "${ROOT}/real-ws" "${ROOT}/ws-link"
        When call validate_path target "cfg/a.yml" "${ROOT}/ws-link"
        The status should equal 0
        The stdout should equal "${ROOT}/ws-link/cfg/a.yml"
      End
      It '[Normal] T-PA-VP-0105: root 内の symlink チェーンは未解決の path を返す'
        _fx_touch "${WS}/real.yml"
        ln -s "${WS}/real.yml" "${WS}/mid.yml"
        ln -s "${WS}/mid.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/link.yml"
      End
      It '[Normal] T-PA-VP-0106: root にだけ空白を含んでも受理する (空白検査は value のみ)'
        mkdir -p "${ROOT}/my ws"
        When call validate_path target "cfg/a.yml" "${ROOT}/my ws"
        The status should equal 0
        The stdout should equal "${ROOT}/my ws/cfg/a.yml"
      End
    End

    Context 'When: 異常系 (字面の検査)'
      It '[Error] T-PA-VP-0201: ".." セグメントを含む value は拒否する'
        When call validate_path target "a/../b" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*a/../b*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0202: 空白 (space) を含む value は拒否する'
        When call validate_path target "a b.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*a b.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0203: tab を含む value は拒否する'
        When call validate_path target $'a\tb.yml' "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0204: root 外の絶対 path は拒否する'
        When call validate_path target "/etc/passwd" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*/etc/passwd*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0205: 空の value は拒否する'
        When call validate_path target "" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*"
        The lines of stderr should equal 1
      End
    End

    Context 'When: 異常系 (realpath の検査)'
      It '[Error] T-PA-VP-0301: root 外ファイルへの symlink は拒否する'
        ln -s "${OUT}/x.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*link.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0302: root 外ディレクトリへの symlink dir 経由は拒否する'
        ln -s "$OUT" "${WS}/dirlink"
        When call validate_path target "dirlink/x.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*dirlink/x.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0303: 2 段 symlink (root 内 -> root 内 -> 外部) は拒否する'
        ln -s "${OUT}/x.yml" "${WS}/mid.yml"
        ln -s "${WS}/mid.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*link.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0304: root 自体が symlink かつ root 外を指す symlink は拒否する'
        mkdir -p "${ROOT}/real-ws"
        ln -s "${ROOT}/real-ws" "${ROOT}/ws-link"
        ln -s "${OUT}/x.yml" "${ROOT}/ws-link/link.yml"
        When call validate_path target "link.yml" "${ROOT}/ws-link"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*link.yml*"
        The lines of stderr should equal 1
      End
      It '[Error] T-PA-VP-0305: 接頭辞が同じ兄弟 (ws-evil) への symlink は拒否する'
        mkdir -p "${ROOT}/ws-evil"
        ln -s "${ROOT}/ws-evil/x.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*link.yml*"
        The lines of stderr should equal 1
      End
    End

    Context 'When: エッジケース'
      It '[Edge] T-PA-VP-0401: ".." を部分文字列に持つ名前は segment ではないので受理する'
        When call validate_path target "a..b.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/a..b.yml"
      End
      It '[Edge] T-PA-VP-0402: dangling symlink は拒否しない'
        ln -s "${WS}/none.yml" "${WS}/link.yml"
        When call validate_path target "link.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/link.yml"
      End
      It '[Edge] T-PA-VP-0403: 存在しない path は拒否しない'
        When call validate_path target "missing/none.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/missing/none.yml"
      End
      It '[Edge] T-PA-VP-0404: realpath が失敗しても set -e で中断しない'
        When call _validate_under_set_e "missing/none.yml" "$WS"
        The status should equal 0
        The stdout should equal "${WS}/missing/none.yml"
      End
      It '[Edge] T-PA-VP-0405: value が root 自体なら拒否する'
        When call validate_path target "$WS" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*"
        The lines of stderr should equal 1
      End
      It '[Edge] T-PA-VP-0406: root 末尾に "/" があっても同じ結果を返す'
        When call validate_path target "cfg/a.yml" "${WS}/"
        The status should equal 0
        The stdout should equal "${WS}/cfg/a.yml"
      End
    End

    Context 'When: 実装を壊すと RED になること (FN 確認)'
      It '[Edge] T-PA-VP-0501: 字面上の兄弟接頭辞 (/ws-evil/x) は拒否する'
        When call validate_path target "${WS}-evil/x.yml" "$WS"
        The status should equal 1
        The stdout should equal ""
        The stderr should match pattern "::error::target:*ws-evil/x.yml*"
        The lines of stderr should equal 1
      End
      It '[Edge] T-PA-VP-0502: 二重 source でも関数が定義済みで guard が立つ'
        When call _source_twice
        The status should equal 0
        The stdout should equal "loaded=1 defined"
      End
    End
  End
End
