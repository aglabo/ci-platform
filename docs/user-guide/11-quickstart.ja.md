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

このページでは、`validate-environment` を最短手順で導入する方法を説明します。

--

## ✅ 前提条件

- GitHub Actions ワークフローが Linux ランナー (`ubuntu-latest` など) で動作すること
- `GITHUB_TOKEN` が利用可能であること (GitHub Actions では自動的に提供されます)

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
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0

      - name: Checkout
        uses: actions/checkout@v4

      # 以降のステップを記述する
```

この設定では以下を検証します。

- ランナーが Linux (amd64) であること
- `GITHUB_TOKEN` が設定されていること (`contents: read` 相当)
- Git と curl がインストールされていること

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

検証でエラーが発生すると、ワークフローはその時点で停止します。
ログには `::error::` 形式のメッセージが出力されるため、原因を確認して設定を修正してください。

よくある原因は次のとおりです。

- `runs-on` が Linux 以外になっている
- `permissions` セクションに必要な権限が記載されていない
- 必須ツール (Git、curl) がカスタムランナーにインストールされていない

---

## 📚 次のステップ

- [利用シナリオ](./12-basic-scenarios.ja.md): commit・PR パーミッションの設定例
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
