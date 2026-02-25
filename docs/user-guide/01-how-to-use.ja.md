---
title: 使い方
description: aglabo/ci-platform の Actions・Workflows を自分のリポジトリから参照して利用する方法
slug: how-to-use
sidebar_position: 1
tags:
  - ci-platform
  - composite-actions
  - reusable-workflow
  - github-actions
---

## 📖 このガイドについて

`aglabo/ci-platform` の Actions・Workflows を自分のリポジトリから参照する方法を説明します。
以下では `aglabo/ci-platform` を ci-platform と表記します。

**前提**: GitHub Actions に慣れており、`steps: uses:` / `jobs: uses:` の使い分けを把握していること。

> **最短で試したい場合** → [クイックスタート](./11-quickstart.ja.md)

---

## 🔗 コンポーネントの参照方法

ci-platform は Composite Action を提供中です。Reusable Workflow は現在 `aglabo/.github` リポジトリから提供されており、将来、`ci-platform` へ集約予定です。

### Composite Action

ワークフローの `steps` から `uses:` キーで参照します。ジョブ内の特定ステップとして実行されます。

```yaml
steps:
  - uses: aglabo/ci-platform/.github/actions/<action-name>@<SHA> # vX.Y.Z
```

### Reusable Workflow

ワークフローの `jobs` から `uses:` キーで参照します。
Reusable Workflow は現在 `aglabo/.github` リポジトリから提供されており、将来、`ci-platform` へ集約予定です。

```yaml
jobs:
  scan:
    uses: aglabo/.github/.github/workflows/<workflow-name>.yml@r1.1.2
```

---

## 🔒 バージョン固定: SHA 固定を使う理由

`@` の後ろにバージョンを指定します。**SHA 固定 + タグコメント形式を強く推奨します。**

<!-- markdownlint-disable line-length -->

| 指定方法           | 例                                                   | 特徴                                         |
| ------------------ | ---------------------------------------------------- | -------------------------------------------- |
| SHA + タグコメント | `@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0` | 最も厳密。改ざん耐性が高い (推奨)            |
| タグ               | `@v0.1.0`                                            | リリース済みバージョンを固定する             |
| ブランチ名         | `@main`                                              | 常に最新。破壊的変更の影響を受ける恐れがある |

<!-- markdownlint-enable line-length -->

タグ (`@v0.1.0`) だけでは参照先のコミットを書き換えられるリスクを排除できません。
SHA 固定により、参照先の内容を変更されても CI への影響をゼロに抑えられます。
本番ワークフローでは SHA 固定 + タグコメント形式を推奨します。
`@main` の使用は推奨しません。

---

## ⚙️ Composite Action の使い方

### validate-environment

CI 冒頭に置くゲートアクションです。ランナー OS・パーミッション・必須ツールを検証し、
ポリシー違反があれば即座にジョブを停止します。
`checkout` より前に配置することで、不正なコードを取得する前に環境を検証できます。

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: read

      - uses: actions/checkout@v4
```

`actions-type` は `permissions` の `actions:` 設定と整合する値を指定します。
詳細は[リファレンス](./13-reference.ja.md)を参照してください。

> Linux 系ランナー専用です。非 Linux ランナー (macOS・Windows) では処理が失敗します。

詳細は以下を参照してください。

- [Validate Environment 概要](./10-about-validate-environment.ja.md)
- [クイックスタート](./11-quickstart.ja.md)
- [利用シナリオ](./12-basic-scenarios.ja.md)
- [リファレンス](./13-reference.ja.md)

---

## 🔄 Reusable Workflow の使い方

actionlint・ghalint・gitleaks の Reusable Workflow は現在 `aglabo/.github` リポジトリから提供されています。
将来的に `ci-platform` リポジトリへ集約予定です。

| 種類              | スコープ     | 責務                    |
| ----------------- | ------------ | ----------------------- |
| Composite Action  | 1 ジョブ内   | 実行前 fail-fast ゲート |
| Reusable Workflow | 複数ジョブ間 | CI 全体へのポリシー強制 |

Composite Action はジョブ内の設定ミスを早期に遮断し、Reusable Workflow は CI 全体にわたるポリシーを強制します。
以下のように参照できます。

```yaml
jobs:
  lint-workflow:
    uses: aglabo/.github/.github/workflows/ci-common-lint-actionlint.yml@r1.1.2

  scan-secrets:
    uses: aglabo/.github/.github/workflows/ci-common-scan-gitleaks.yml@r1.1.2
```

現在の実装状況の詳細は [ci-platform とは](./00-platform-overview.ja.md#️-現在の実装状況) を参照してください。

---

## 🔰 CI 構成サンプル

`validate-environment` と Reusable Workflow を組み合わせた、コピペで動く最小フル構成です。

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  # Reusable Workflow: ワークフロー構文検証
  lint-workflow:
    uses: aglabo/.github/.github/workflows/ci-common-lint-actionlint.yml@r1.1.2

  # Reusable Workflow: シークレットスキャン
  scan-secrets:
    uses: aglabo/.github/.github/workflows/ci-common-scan-gitleaks.yml@r1.1.2

  # Composite Action: 実行環境検証 + ビルド
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: read

      - uses: actions/checkout@v4

      # 以降に通常のビルドステップを追加
```

> SHA は最新の値に更新してから使用してください。

さらに詳細な使い方 (複数ジョブの組み合わせ・段階導入パターンなど) は [利用シナリオ](./12-basic-scenarios.ja.md) を参照してください。

---

## ⚠️ よくあるミス

<!-- markdownlint-disable line-length -->

| ミス                              | 症状                                                          | 対処                                          |
| --------------------------------- | ------------------------------------------------------------- | --------------------------------------------- |
| SHA とタグを混在させる            | `@v0.1.0` のみ指定 → タグ書き換えで別コードが動く可能性がある | SHA 固定 + タグコメント形式に統一する         |
| `permissions:` を未設定のまま使う | validate-environment が権限不足を検出してジョブが即終了する   | `permissions: contents: read` を明示する      |
| 非 Linux ランナーで実行する       | macOS・Windows ランナーでは最初のステップで失敗する           | `runs-on: ubuntu-latest` を指定する           |
| `checkout` より後に配置する       | 不正コードをチェックアウト後に検証が走り意味が薄れる          | `validate-environment` を最初のステップに置く |

<!-- markdownlint-enable line-length -->

### 実際のエラー例

非 Linux ランナーを指定した場合、次のエラーが出力されます。

```text
::error::Unsupported OS: darwin (Linux required)
::error::This action requires Linux
::error::Please use a Linux runner (e.g., ubuntu-latest)
```

`permissions:` が不足して `actions-type: commit` を指定した場合は次のエラーになります。

```text
::error::contents: write permission not granted
::error::For GITHUB_TOKEN, configure permissions: contents: write
```

いずれもログ先頭に出力されます。`runs-on` または `permissions:` の設定を確認してください。

---

## 📚 関連ドキュメント

- [ci-platform とは](./00-platform-overview.ja.md): プロジェクト概要と設計方針
- [Validate Environment 概要](./10-about-validate-environment.ja.md): validate-environment の詳細
- [クイックスタート](./11-quickstart.ja.md): 最小構成での導入手順
