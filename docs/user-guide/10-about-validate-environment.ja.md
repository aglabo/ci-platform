---
title: Validate Environment 概要
description: GitHub Actions ランナーの OS・パーミッション・アプリケーションを検証する Composite Action の概要
slug: about-validate-environment
sidebar_position: 10
tags:
  - validate-environment
  - composite-action
  - github-actions
---

## ⚙️ Validate Environment とは

`validate-environment` は、GitHub Actions ワークフロー内でランナー環境を事前に検証する **Composite Action** です。
ワークフロー本体の実行前に OS・パーミッション・必要ツールを確認し、設定ミスによる失敗を早期に検知できます。

## 🎯 解決する問題

GitHub Actions のワークフローは、実行環境の前提条件が満たされていない場合に失敗します。
たとえば、以下のような状況が考えられます。

- 想定と異なる OS・アーキテクチャのランナーでジョブが起動する
- 必要な GitHub パーミッションが不足しているため、API 呼び出しや書き込みに失敗する
- 依存ツールがインストールされていないため、途中でワークフローが停止する

`validate-environment` をワークフローの冒頭に配置することで、これらの問題を**早期に検出してエラーを明示**できます。

## ✅ 検証する内容

`validate-environment` は 3 つの検証を順に実行します。

| 検証                        | 内容                                                           |
| --------------------------- | -------------------------------------------------------------- |
| ランナー環境の検証          | OS が Linux であること、アーキテクチャが期待値と一致すること   |
| GitHub パーミッションの検証 | `actions-type` に応じた GitHub トークンの権限を確認            |
| アプリケーションの検証      | Git・curl などの必須ツールが存在し、バージョン要件を満たすこと |

## 🔒 制約事項

> **Linux ランナー専用**です (`ubuntu-latest` など)。
> Windows および macOS はサポートしていません。

## 🪟 ランナー環境の検証

OS が Linux であること、および CPU アーキテクチャが期待値と一致することを確認します。

| 項目                 | 内容                                                         |
| -------------------- | ------------------------------------------------------------ |
| サポート OS          | Linux のみ (`ubuntu-latest`、`ubuntu-22.04` など)            |
| アーキテクチャ       | `amd64`（デフォルト）または `arm64`                          |
| セルフホストランナー | デフォルトで許可。`require-github-hosted: "true"` で制限可能 |

## 🔑 GitHub パーミッションの検証

`actions-type` 入力に応じて、GitHub トークンが必要な権限を持っているかを検証します。

| `actions-type` 値    | 必要なパーミッション                       | 用途                         |
| -------------------- | ------------------------------------------ | ---------------------------- |
| `read`（デフォルト） | `contents: read`                           | コード参照のみ               |
| `commit`             | `contents: write`                          | コードのプッシュを含む       |
| `pr`                 | `contents: write` + `pull-requests: write` | PR の作成・更新を含む        |
| `any`                | チェックなし                               | 権限検証をスキップしたい場合 |

## 📦 アプリケーションの検証

Git と curl をデフォルトで検証します。`additional-apps` 入力を使うと、任意のツールをバージョン要件付きで追加できます。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@main
  with:
    additional-apps: |
      gh|gh|regex:version ([0-9.]+)|2.0
      node|Node.js|regex:v([0-9.]+)|20.0
```

## 📤 出力値

各検証の結果は `status` と `message` のペアで出力されます。

| 出力名                | 値                  | 説明                                 |
| --------------------- | ------------------- | ------------------------------------ |
| `runner-status`       | `success` / `error` | ランナー検証の結果                   |
| `runner-message`      | 文字列              | ランナー検証の詳細メッセージ         |
| `permissions-status`  | `success` / `error` | パーミッション検証の結果             |
| `permissions-message` | 文字列              | パーミッション検証の詳細メッセージ   |
| `apps-status`         | `success` / `error` | アプリケーション検証の結果           |
| `apps-message`        | 文字列              | アプリケーション検証の詳細メッセージ |

## 📚 関連ドキュメント

- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
