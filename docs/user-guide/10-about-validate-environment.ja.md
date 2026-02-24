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

本アクションは **CI Platform における環境検証レイヤー**を担います。
後続のプロビジョニングや CI ステップの前段に配置することで、実行環境の正当性を入口で保証する**初期ゲート**として機能します。

## 🎯 解決する問題

GitHub Actions のワークフローは、実行環境の前提条件が満たされていない場合に失敗します。
たとえば、以下のような状況が考えられます。

- 想定と異なる OS・アーキテクチャのランナーでジョブが起動する
- 必要な GitHub パーミッションが不足しているため、API 呼び出しや書き込みに失敗する
- 依存ツールがインストールされていないため、途中でワークフローが停止する

`validate-environment` をワークフローの冒頭に配置することで、
これらの問題を**早期に検出する fail-fast ゲート**として機能します。

## ✅ 検証する内容

`validate-environment` は以下の 3つの検証を順に実行します。
いずれかが失敗した時点でジョブを即座に終了します (fail-fast)。

この順序は依存関係にもとづきます。ランナーが正常でなければパーミッションを検証できず、
パーミッションが不足していれば、後続のアプリ検証が成立しないためです。

| 検証                        | 役割         | 内容                                                           |
| --------------------------- | ------------ | -------------------------------------------------------------- |
| ランナー環境の検証          | 実行前提     | OS が Linux であること、アーキテクチャが期待値と一致すること   |
| GitHub パーミッションの検証 | セキュリティ | `actions-type` に応じた GitHub トークンの権限を確認            |
| アプリケーションの検証      | 実行要件     | Git・curl などの必須ツールが存在し、バージョン要件を満たすこと |

## 🔒 制約事項：Linux 専用の設計判断

本アクションは **Linux ランナー専用**です (`ubuntu-latest`、`ubuntu-22.04` など) 。
Windows・macOS はサポートしていません。

Linux 専用とした理由は次のとおりです。

- 検証スクリプトは Bash を前提に設計されています
- GitHub Hosted Linux ランナーは一定のバージョンポリシーのもとで提供されます
- Linux 環境に統一することで CI の再現性が高まります

## 🪟 ランナー環境の検証

OS が Linux であること、および CPU アーキテクチャが期待値と一致することを確認します。

| 項目                 | 内容                                                         |
| -------------------- | ------------------------------------------------------------ |
| サポート OS          | Linux のみ (`ubuntu-latest`、`ubuntu-22.04` など)            |
| アーキテクチャ       | `amd64` (デフォルト) または `arm64`                          |
| セルフホストランナー | デフォルトで許可。`require-github-hosted: "true"` で制限可能 |

> 補足:
> アーキテクチャは、`inputs: architecture`で指定します。省略時は、`amd64` が適用されます。

## 🔑 GitHub パーミッションの検証

`actions-type` 入力に応じて、GitHub トークンが必要な権限を持っているかを検証します。

<!-- markdownlint-disable line-length -->

| `actions-type` 値   | 必要なパーミッション                       | 用途                                                                                  |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| `read` (デフォルト) | `contents: read`                           | コード参照のみ                                                                        |
| `commit`            | `contents: write`                          | コードのプッシュを含む                                                                |
| `pr`                | `contents: write` + `pull-requests: write` | PR の作成・更新を含む                                                                 |
| `any`               | 権限プローブをスキップ                     | GitHub パーミッションの詳細検証をスキップします。ランナー・アプリ検証には影響しません |

<!-- markdownlint-enable -->

## 📦 アプリケーションの検証

Git と curl をデフォルトで検証します。`additional-apps` 入力を使うと、任意のツールをバージョン要件付きで追加できます。

各アプリは `cmd|表示名|バージョン抽出方式|最低バージョン` の形式で指定します。
バージョン抽出方式には `regex:PATTERN` (正規表現) と `field:N` (スペース区切りの N 番目のフィールド) を指定できます。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
  with:
    additional-apps: |
      gh|GitHub CLI|field:3|2.0
      node|Node.js|regex:v([0-9.]+)|20.0
      jq|jq|regex:([0-9.]+)|1.6
```

> 補足:
> 安全のため、使用できる正規表現には制限があります。詳細は[リファレンス](./13-reference.ja.md)を参照してください。

## 📤 出力値

各検証の結果は `status` と `message` のペアで出力されます。

> いずれかの検証が `error` を返した場合、アクションはジョブを失敗させます。
> 出力値は後続ステップから `steps.<id>.outputs.<name>` で参照できます。
> Reusable Workflow では `jobs.<id>.outputs` を介して他ジョブへ伝達できます。

| 出力名                | 型       | 値域                 | 説明                                 |
| --------------------- | -------- | -------------------- | ------------------------------------ |
| `runner-status`       | `string` | `success` \| `error` | ランナー検証の結果                   |
| `runner-message`      | `string` | 任意の文字列         | ランナー検証の詳細メッセージ         |
| `permissions-status`  | `string` | `success` \| `error` | パーミッション検証の結果             |
| `permissions-message` | `string` | 任意の文字列         | パーミッション検証の詳細メッセージ   |
| `apps-status`         | `string` | `success` \| `error` | アプリケーション検証の結果           |
| `apps-message`        | `string` | 任意の文字列         | アプリケーション検証の詳細メッセージ |

## 📚 関連ドキュメント

- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
