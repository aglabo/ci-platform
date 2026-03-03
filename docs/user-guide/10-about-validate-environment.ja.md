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

CI は設定が誤ったまま実行されると、後続ステップで権限超過・シークレット漏洩・意図しないデプロイといった破壊的な操作を引き起こす可能性があります。
`validate-environment` は、CI パイプラインの最初のステップに配置し、誤った設定を早期に発見する **fail-fast** ゲートです。

ランナー OS・パーミッション・必須ツールをジョブ実行の前段で検証し、
ポリシー違反・権限不足・環境不整合を即座に検出します。
問題が検出された時点でジョブを強制停止し、後続ステップへの進行を遮断します。

```yaml
steps:
  # checkout より前に配置することで、環境不整合を最初のステップで検知する
  - name: Validate environment
    uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
```

---

## 🎯 設計目標

`validate-environment` は次の 3つを目標として設計されています。

- CI の破壊的操作を最初のステップで遮断する
- セキュリティポリシーをコードとして定義・強制する
- Linux ランナーに統一することで CI 実行環境の再現性を担保する

---

## ✅ 検証する内容

3 段階の検証を順に実行します。いずれかが失敗した時点でジョブを即座に終了します。

| ステップ          | 検証内容                                                          |
| ----------------- | ----------------------------------------------------------------- |
| 1. ランナー       | OS が Linux であること。アーキテクチャが期待値と一致すること      |
| 2. パーミッション | `actions-type` に応じた GitHub トークンの権限が付与されていること |
| 3. アプリ         | Git・curl などの必須ツールが存在し、バージョン要件を満たすこと    |

この順序は依存関係に基づきます。ランナーが不正であればパーミッション検証は意味を持たず、
パーミッションが不足していればアプリ検証の実行自体が無意味になります。

---

## 🔒 制約: Linux 専用

**Linux ランナー専用** (`ubuntu-latest` / `ubuntu-22.04` など)。Windows・macOS はサポート対象外です。

検証スクリプトは Bash と GNU ツールに依存しており、Linux に統一することで CI の再現性を確保しています。

次のケースには適していません。

- macOS・Windows ランナーのみを使用している
- ローカル再現性が不要な一時的な CI スクリプト

---

## 🪟 ランナー環境の検証

| 項目           | 内容                                                         |
| -------------- | ------------------------------------------------------------ |
| サポート OS    | Linux のみ (`ubuntu-latest`・`ubuntu-22.04` など)            |
| アーキテクチャ | `amd64` (デフォルト) または `arm64`                          |
| セルフホスト   | デフォルトで許可。`require-github-hosted: "true"` で制限可能 |

アーキテクチャは `inputs: architecture` で指定します。省略時は `amd64` が適用されます。

---

## 🔑 GitHub パーミッションの検証

`actions-type` に応じて、GitHub トークンの権限を検証します。
`permissions` セクションの設定と必ず整合させてください。

<!-- markdownlint-disable line-length -->

| `actions-type` 値   | 必要な permissions                         | 用途                                           |
| ------------------- | ------------------------------------------ | ---------------------------------------------- |
| `read` (デフォルト) | `contents: read`                           | コード参照のみ                                 |
| `commit`            | `contents: write`                          | コードのプッシュを含む                         |
| `pr`                | `contents: write` + `pull-requests: write` | PR の作成・更新を含む                          |
| `any`               | 権限プローブをスキップ                     | パーミッション検証をスキップ。例外的な用途専用 |

<!-- markdownlint-enable -->

### GITHUB_TOKEN の設定

デフォルトでは `${{ github.token }}` (ジョブに自動付与されるトークン) を使用します。
通常はトークンを明示的に渡す必要はありません。

```yaml
permissions:
  contents: read

steps:
  - name: Validate environment
    uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
    with:
      actions-type: read
    # github-token は省略可。${{ github.token }} が自動的に使われる
```

PAT など別のトークンを使う場合は `github-token` に明示的に渡します。

```yaml
steps:
  - name: Validate environment
    uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
    with:
      actions-type: commit
      github-token: ${{ secrets.MY_PAT }}
```

> `read` モードはトークンの存在確認のみで、API プローブは行いません。
> `commit` / `pr` モードは GitHub API への書き込みプローブで権限を確認します。

---

## 📦 アプリケーションの検証

Git と curl をデフォルトで検証します。`additional-apps` で任意のツールをバージョン要件付きで追加できます。

各アプリは `cmd|表示名|バージョン抽出方式|最低バージョン` の形式で指定します。

```yaml
- uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
  with:
    additional-apps: |
      gh|GitHub CLI|field:3|2.0
      node|Node.js|regex:v([0-9.]+)|20.0
      jq|jq|regex:([0-9.]+)|1.6
```

> 安全のため、正規表現には文字種の制限があります。詳細は[リファレンス](./13-reference.ja.md)を参照してください。

---

## 📤 出力値

各検証結果は `status` / `message` のペアで出力されます。
いずれかが `error` を返した場合、アクションは即時に非ゼロの終了コードで終了します。

| 出力名                | 値域                | 説明                                 |
| --------------------- | ------------------- | ------------------------------------ |
| `runner-status`       | `success` / `error` | ランナー検証の結果                   |
| `runner-message`      | 任意の文字列        | ランナー検証の詳細メッセージ         |
| `permissions-status`  | `success` / `error` | パーミッション検証の結果             |
| `permissions-message` | 任意の文字列        | パーミッション検証の詳細メッセージ   |
| `apps-status`         | `success` / `error` | アプリケーション検証の結果           |
| `apps-message`        | 任意の文字列        | アプリケーション検証の詳細メッセージ |

出力値は後続ステップから `steps.<id>.outputs.<name>` で参照できます。
たとえば、ランナー検証が失敗したときだけ追加の診断ステップを実行できます。

```yaml
steps:
  - name: Validate environment
    id: validate
    uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
    with:
      actions-type: read

  - name: Show runner error detail
    if: steps.validate.outputs.runner-status == 'error'
    run: echo "${{ steps.validate.outputs.runner-message }}"
```

---

## 📚 関連ドキュメント

- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
