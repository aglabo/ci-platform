---
title: "ci-platform Release Notes v0.3.1"
version: "0.3.1"
date: 2026-06-22
tags:
  - release
  - composite-actions
summary: >
  v0.3.1 では、push イベントでコミット間の変更ファイルを検出する
  ca-get-changed-files コンポジットアクションを追加しました。
---

## [0.3.1] - 2026-06-22

### Overview

このリリースでは、`ca-get-changed-files` コンポジットアクションを新たに追加しました。

push イベントの before/after コミット間で変更されたファイルを取得し、
glob パターンによるフィルタリングに対応します。
変更ファイルの一覧と件数を出力として提供するため、
後続のジョブやステップで条件分岐・ファイル処理に活用できます。

---

### Added

#### Composite Actions

- `ca-get-changed-files`: push イベントで変更されたファイルを検出するコンポジットアクション。

  入力パラメータ:

  | パラメータ   | 必須 | デフォルト            | 説明                                 |
  | ------------ | ---- | --------------------- | ------------------------------------ |
  | `pattern`    | 任意 | `""` (全ファイル)     | 変更ファイルを絞り込む glob パターン |
  | `before-sha` | 任意 | `github.event.before` | 比較元コミット SHA                   |
  | `after-sha`  | 任意 | `github.sha`          | 比較先コミット SHA                   |

  出力:

  | 出力    | 説明                                 |
  | ------- | ------------------------------------ |
  | `files` | 変更ファイルのパス一覧（改行区切り） |
  | `count` | 変更ファイルの件数                   |

  前提条件: `actions/checkout` で `fetch-depth: 0` の設定が必須です。

  使用例:

  ```yaml
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0

  - uses: aglabo/ci-platform/.github/actions/ca-get-changed-files@v0.3.1
    id: changed
    with:
      pattern: "src/**/*.ts"

  - run: echo "Changed files: ${{ steps.changed.outputs.files }}"
  ```

---

### Notes

- `ca-get-changed-files` はパターンなし・マッチあり・マッチなしのシナリオを含む
  インテグレーションテストで動作を検証済みです。
