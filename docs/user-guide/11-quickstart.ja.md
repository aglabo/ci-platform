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

`validate-environment` を既存のワークフローに組み込む最小手順を示します。

**前提**:

- Linux ランナー (`ubuntu-latest` など) を使用していること
- `GITHUB_TOKEN` に `contents: read` 権限が付与されていること

---

## 📝 最小構成

まずは以下の最小構成をそのままコピーして試してください。

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # checkout より前に配置して環境不整合を最初に検知する
      - name: Validate environment
        id: validate
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
      # SHA は Dependabot または Renovate で自動更新できます

      - name: Checkout
        uses: actions/checkout@v4

      - name: Show results
        run: |
          echo "runner  : ${{ steps.validate.outputs.runner-status }}"
          echo "perms   : ${{ steps.validate.outputs.permissions-status }}"
          echo "apps    : ${{ steps.validate.outputs.apps-status }}"

      # 以降のステップを記述する
```

この設定で以下を検証します。

- ランナーが Linux であること (デフォルト: `amd64`。`arm64` を使う場合は `with: architecture: arm64`)
- `GITHUB_TOKEN` に `contents: read` 権限が付与されていること
- Git と curl がインストールされていること

---

## 🔍 出力を確認する

`id: validate` を付けると、後続ステップから `steps.validate.outputs.<name>` で結果を参照できます。
各出力は `success` または `error` のいずれかです。

上記の最小構成には `Show results` ステップが含まれており、実行するとログに以下が出力されます。

```text
runner  : success
perms   : success
apps    : success
```

出力値の一覧:

| 出力名               | 値                  | 説明                       |
| -------------------- | ------------------- | -------------------------- |
| `runner-status`      | `success` / `error` | ランナー検証の結果         |
| `permissions-status` | `success` / `error` | パーミッション検証の結果   |
| `apps-status`        | `success` / `error` | アプリケーション検証の結果 |

各出力の詳細は[リファレンス](./13-reference.ja.md)を参照してください。

---

## ⚠️ 検証に失敗した場合

検証エラーはアクションを非ゼロの終了コードで終了させます。
ログには `::error::` 形式でメッセージが出力されます。

よくある原因:

- `runs-on` が Linux 以外になっている
- `permissions` セクションに必要な権限が記載されていない
- 必須ツール (Git・curl) がカスタムランナーにインストールされていない

詳細は[トラブルシューティング](./90-troubleshooting.ja.md)を参照してください。

---

## 📚 次のステップ

- [利用シナリオ](./12-basic-scenarios.ja.md): commit・PR パーミッションの設定例 (`actions-type: commit` など)
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
