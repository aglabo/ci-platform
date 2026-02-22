---
title: クイックスタート
description: validate-environment を最小構成で導入する手順
slug: quickstart
sidebar_position: 11
tags:
  - validate-environment
  - quickstart
  - github-actions
---

## 🚀 クイックスタート

最小構成で `validate-environment` を導入する手順を示します。

## ✅ 前提条件

- GitHub Actions ワークフローが Linux ランナー (`ubuntu-latest` など) で動作すること
- `GITHUB_TOKEN` に必要な権限が付与されていること（`permissions` セクションで明示的に指定します）

## 📝 最小構成

以下は、`validate-environment` を使った最小構成のワークフローです。

```yaml
name: CI

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # ゲートとして機能させるため checkout より前に配置します
      - name: Validate environment
        id: validate
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0

      - name: Checkout
        uses: actions/checkout@v4

      # 以降のステップを記述する
```

この設定では以下を検証します。

- ランナーが Linux であること（デフォルトは `amd64`。`arm64` は `architecture` 入力で指定）
- `GITHUB_TOKEN` に `contents: read` 権限が付与されていること（`actions-type: read` のデフォルト要件）
- Git と curl がインストールされていること

出力値を参照しなくても利用できます。検証が通過すれば後続ステップがそのまま実行されます。

## 🔍 出力を確認する

検証の結果は後続のステップから参照できます。

```yaml
steps:
  - name: Validate environment
    id: validate
    uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0

  - name: Show results
    run: |
      echo "runner  : ${{ steps.validate.outputs.runner-status }}"
      echo "perms   : ${{ steps.validate.outputs.permissions-status }}"
      echo "apps    : ${{ steps.validate.outputs.apps-status }}"
```

各出力は `success` または `error` のいずれかです。

## ⚠️ 検証に失敗した場合

検証でエラーが発生すると、アクションは非ゼロの終了コードを返し、ワークフローはその時点で停止します。
ログには `::error::` 形式（GitHub Actions の標準エラー表示）のメッセージが出力されるため、原因を確認して設定を修正してください。

よくある原因は次のとおりです。

- `runs-on` が Linux 以外になっている
- `permissions` セクションに必要な権限が記載されていない
- 必須ツール (Git、curl) がカスタムランナーにインストールされていない

---

## 📚 次のステップ

- [利用シナリオ](./12-basic-scenarios.ja.md): commit・PR パーミッションの設定例
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
