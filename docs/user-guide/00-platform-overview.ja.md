---
title: ci-platform とは
description: OSS 開発のための CI/品質管理基盤の概要
slug: about-ci-platform
sidebar_position: 0
tags:
  - ci-platform
  - composite-actions
  - github-actions
  - git-hooks
---

## 🏗️ ci-platform とは

`ci-platform` は、OSS 開発のための **CI/品質管理基盤**です。
GitHub Actions の Composite Actions と再利用可能ワークフローを公開・配布するリポジトリであり、自分のリポジトリから参照して利用します。

---

## 🎯 解決する問題

OSS 開発では、次のような品質管理の課題が生じやすいです。

- コミット時にシークレット情報や機密データを混入するリスクがある
- GitHub Actions ワークフローの設定ミスが CI 実行時まで発覚しない
- 開発者によってコミットメッセージの形式がばらつく
- ドキュメントの表記揺れや文法ミスが蓄積する

`ci-platform` が公開する Actions やワークフローを参照することで、これらの問題に対処する品質管理の仕組みを**自分のリポジトリに取り込めます**。

---

## 📦 提供コンポーネント

### 現在提供中

<!-- markdownlint-disable line-length MD060 -->

| 種類             | コンポーネント       | 説明                                                             |
| ---------------- | -------------------- | ---------------------------------------------------------------- |
| Composite Action | validate-environment | GitHub Actions ランナーの OS・パーミッション・ツールを検証します |

<!-- markdownlint-enable line-length MD060 -->

### 提供予定 (Reusable Workflow)

<!-- markdownlint-disable line-length MD060 -->

| コンポーネント | 説明                                  |
| -------------- | ------------------------------------- |
| actionlint     | GitHub Actions ワークフローの構文検証 |
| ghalint        | GitHub Actions のポリシー違反検出     |
| gitleaks       | リポジトリ全体の機密情報スキャン      |

<!-- markdownlint-enable line-length MD060 -->

> 上記のツールは現在 ci-platform 自身の CI で使用しています。
> 将来的に reusable workflow として公開し、外部リポジトリから直接参照できるようにする予定です。

---

## 🔧 品質管理の 3 つの柱

OSS 開発における品質管理は、次の 3 つの領域に分けられます。

| 領域                 | 対象               | ci-platform での提供 |
| -------------------- | ------------------ | -------------------- |
| ローカル品質管理     | Git Hooks          | 対象外               |
| **CI/CD 品質管理**   | **GitHub Actions** | **提供中・提供予定** |
| ドキュメント品質管理 | textlint など      | 対象外               |

**ci-platform が提供するのは CI/CD 品質管理の領域のみです。**
ローカル品質管理やドキュメント品質管理のツールは、利用者が各自で導入してください。

### CI/CD 品質管理 (GitHub Actions)

(main ブランチへの)Push・PR 時に GitHub Actions が自動実行し、ワークフロー定義を検証します。
現在は ci-platform 自身の CI に組み込まれており、外部への reusable workflow 提供は予定中です。

| ツール     | 目的                                  | 外部提供 |
| ---------- | ------------------------------------- | -------- |
| actionlint | GitHub Actions ワークフローの構文検証 | 予定     |
| ghalint    | GitHub Actions のポリシー違反を検出   | 予定     |
| gitleaks   | リポジトリ全体のシークレットスキャン  | 予定     |

---

## 🚀 利用方法

自分のリポジトリの GitHub Actions ワークフローから Composite Actions を参照して利用します。
`ci-platform` のリポジトリ自体をフォークする必要はありません。

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
```

> **Linux ランナー専用です。**
> Windows および macOS はサポートしていません (`ubuntu-latest`、`ubuntu-22.04` など Linux 系ランナーで使用してください)。

---

## 🗺️ ロードマップ

将来的には、actionlint・ghalint・gitleaks を reusable workflow として ci-platform に集約する予定です。
これにより、ワークフローの構文検証・ポリシー検証・機密情報スキャンを、外部リポジトリから一行で参照できるようになります。

```yaml
# 将来の利用イメージ
jobs:
  scan:
    uses: aglabo/ci-platform/.github/workflows/scan-gitleaks.yml@v1
```

---

## 📚 関連ドキュメント

- [使い方](./01-how-to-use.ja.md): 各種アクション・ワークフローの利用手順
- [Validate Environment 概要](./10-about-validate-environment.ja.md): validate-environment の詳細
- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
