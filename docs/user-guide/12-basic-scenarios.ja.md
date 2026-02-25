---
title: 利用シナリオ
description: validate-environment の典型的な利用例 (read / commit / PR パーミッション)
slug: basic-scenarios
sidebar_position: 12
tags:
  - validate-environment
  - scenarios
  - github-actions
---

## 🗂 利用シナリオ

`actions-type` ごとの典型的な利用例を示します。
`actions-type` は `permissions` セクションと必ず整合させてください。

### 権限マトリクス

| `actions-type` | `contents` | `pull-requests` | 用途                          |
| -------------- | ---------- | --------------- | ----------------------------- |
| `read`         | `read`     | —               | 参照・検証のみ (デフォルト)   |
| `commit`       | `write`    | —               | コミット・プッシュ操作        |
| `pr`           | `write`    | `write`         | プルリクエスト作成・更新      |
| `any`          | 任意       | 任意            | 例外用途 (権限検証をスキップ) |

---

## シナリオ 1: コード参照のみ (read)

**目的**: lint・テスト・ビルドなど、リポジトリへの書き込みを伴わないジョブの構成例。

最小権限のベースライン。`actions-type` を省略した場合のデフォルトです。

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
      # actions-type: read (default)

      - uses: actions/checkout@v4
      - name: Run linter
        run: pnpm lint
```

---

## シナリオ 2: コミット・プッシュ操作 (commit)

**目的**: 自動フォーマット・自動生成コードなど、リポジトリへの書き戻しが必要なジョブの構成例。

自動フォーマットや自動生成コードのコミットなど、リポジトリへの書き戻しが必要な場合。

```yaml
jobs:
  auto-format:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: commit

      - uses: actions/checkout@v4
      - name: Format and commit
        run: |
          dprint fmt
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || git commit -m "style: auto format"
          git push
```

---

## シナリオ 3: プルリクエスト操作 (pr)

**目的**: PR を自動作成・更新するジョブの構成例。

PR を作成・更新するワークフロー向け。GitHub CLI (`gh`) を使う場合は `additional-apps` で事前確認します。

```yaml
jobs:
  create-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: pr
          additional-apps: |
            gh|GitHub CLI|field:3|2.0

      - uses: actions/checkout@v4
      - name: Create pull request
        run: |
          gh pr create \
            --title "chore: automated update" \
            --body "自動生成された PR です。" \
            --base main
```

> `gh` CLI は `GITHUB_TOKEN` 環境変数を自動的に使用します。

---

## シナリオ 4: 追加ツールの検証 (additional-apps)

**目的**: デフォルト (Git・curl) 以外のツールをバージョン要件付きで事前検証する構成例。

デフォルト (Git・curl) 以外のツールをバージョン要件付きで検証する場合。

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: commit
          additional-apps: |
            gh|GitHub CLI|field:3|2.0
            node|Node.js|regex:v([0-9.]+)|20.0
            jq|jq|regex:([0-9.]+)|1.6
```

<!-- markdownlint-disable line-length MD060 -->

| 列    | 意味                                                                    |
| ----- | ----------------------------------------------------------------------- |
| 1列目 | コマンド名 (PATH 上の実行ファイル名)                                    |
| 2列目 | 表示名 (ログやエラーメッセージで使用)                                   |
| 3列目 | バージョン抽出方法 (`field:N` / `regex:PATTERN` / 空欄=自動抽出)        |
| 4列目 | 最低バージョン (空欄にするとバージョンチェックをスキップして警告を出す) |

<!-- markdownlint-enable line-length MD060 -->

> `additional-apps` はインストーラーではなく、既存ツールの検証ゲートです。
> ツールのセットアップは別ステップで行ってください。

---

## シナリオ 5: パーミッション検証をスキップ (any)

**目的**: 権限検証が不要な例外的ケース専用。通常のワークフローでは使用しないでください。

特殊な権限構成や、パーミッション検証が不要な例外的ケース向け。
`GITHUB_TOKEN` の存在確認のみ行い、権限プローブは実行しません。

```yaml
jobs:
  special:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
        with:
          actions-type: any
```

> **警告**: `any` は例外的な用途専用です。通常のワークフローでは使用しないでください。
> `read` / `commit` / `pr` のいずれかを明示的に指定することを強く推奨します。

---

## 📚 関連ドキュメント

- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
