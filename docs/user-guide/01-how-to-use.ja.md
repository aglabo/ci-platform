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

`aglabo/ci-platform` が提供するコンポーネントの利用方法を説明します。
以下では `aglabo/ci-platform` を ci-platform と表記します。
ci-platform は Linux ランナーのみを対象として設計されており、macOS および Windows ランナーには対応していません。
ci-platform のリポジトリをフォークする必要はありません。

---

## 🔗 コンポーネントの参照方法

ci-platform は Composite Action を提供中です。Reusable Workflow は v0.2.x で公開予定です。

### Composite Action

ワークフローの `steps` から `uses:` キーで参照します。

```yaml
steps:
  - uses: aglabo/ci-platform/.github/actions/<action-name>@<version>
```

### Reusable Workflow (提供予定)

ワークフローの `jobs` から `uses:` キーで参照します。

```yaml
jobs:
  scan:
    uses: aglabo/ci-platform/.github/workflows/<workflow-name>.yml@<version>
```

---

## 📌 バージョンの指定

`@` の後ろにバージョンを指定します。

<!-- markdownlint-disable line-length MD060 -->

| 指定方法     | 例         | 特徴                                         |
| ------------ | ---------- | -------------------------------------------- |
| タグ         | `@v0.1.0`  | 推奨。リリース済みバージョンを固定する       |
| コミット SHA | `@abc1234` | 最も厳密。改ざん耐性が高い                   |
| ブランチ名   | `@main`    | 常に最新。破壊的変更の影響を受ける恐れがある |

<!-- markdownlint-enable line-length MD060 -->

本番ワークフローではタグまたはコミット SHA による固定を推奨します。
再現性を最大化する場合はコミット SHA 固定を推奨します。

---

## ⚙️ Composite Action の使い方

### validate-environment

GitHub Actions ランナーの OS・パーミッション・ツールを検証する Composite Action です。
ワークフロー冒頭に配置することで、設定ミスによる失敗を早期に検出できます。

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
        with:
          actions-type: read
```

> `ubuntu-latest`・`ubuntu-22.04` など Linux 系ランナーで使用してください。

詳細は以下を参照してください。

- [Validate Environment 概要](./10-about-validate-environment.ja.md)
- [クイックスタート](./11-quickstart.ja.md)
- [利用シナリオ](./12-basic-scenarios.ja.md)
- [リファレンス](./13-reference.ja.md)

---

## 🔄 Reusable Workflow の使い方 (提供予定)

actionlint・ghalint・gitleaks の Reusable Workflow は v0.2.x 系で順次公開予定です。
Composite Action はジョブ内の検証用途、Reusable Workflow は CI 全体の標準化用途を想定しています。
公開後は、以下のように参照できます。

```yaml
# 将来の利用イメージ (v0.2.x 以降)
jobs:
  lint-workflow:
    uses: aglabo/ci-platform/.github/workflows/actionlint.yml@v0.2.0

  scan-secrets:
    uses: aglabo/ci-platform/.github/workflows/scan-gitleaks.yml@v0.2.0
```

ロードマップの詳細は [ci-platform とは](./00-about-ci-platform.ja.md#️-ロードマップ) を参照してください。

---

## 📚 関連ドキュメント

- [ci-platform とは](./00-about-ci-platform.ja.md): プロジェクト概要とロードマップ
- [Validate Environment 概要](./10-about-validate-environment.ja.md): validate-environment の詳細
