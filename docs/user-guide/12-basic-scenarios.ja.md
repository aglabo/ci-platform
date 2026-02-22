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

本アクションは CI の入口ゲートとして設計されています。
このページでは、`actions-type` ごとの典型的な利用例を示します。
権限の強さに応じて `read` → `commit` → `pr` の順で例を示します。
再現性確保のため、固定バージョンの使用を推奨します。

---

## シナリオ 1: コード参照のみ (read)

コードの読み取りや検証をするワークフロー向けの設定です。
`read` は最小権限のベースラインであり、`actions-type` を省略した場合のデフォルトです。

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      # CI の入口ゲートとして機能させるため checkout より前に配置します
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
        # actions-type: read (default)

      - uses: actions/checkout@v4
      - name: Run linter
        run: pnpm lint
```

補足:

- `contents: read` はワークフローの動作に必要な最小限のパーミッションです。
  明示的に記述することを推奨します。

---

## シナリオ 2: コミット・プッシュ操作 (commit)

コードの変更をリポジトリに書き戻すワークフロー向けの設定です。
自動フォーマットや自動生成コードのコミットなどで使用します。

```yaml
jobs:
  auto-format:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      # CI の入口ゲートとして機能させるため checkout より前に配置します
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
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

補足:

- `contents: write` を付与することで、コミット権限の事前確認をします。

---

## シナリオ 3: プルリクエスト操作 (pr)

PR を作成・更新するワークフロー向けの設定です。
`gh` CLI を使って PR を作成する場合は、`additional-apps` で事前にインストール確認をします。

```yaml
jobs:
  create-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      # CI の入口ゲートとして機能させるため checkout より前に配置します
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
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

補足:

- `pull-requests: write` と `contents: write` の両方を付与してください。
- `gh` CLI は `GITHUB_TOKEN` 環境変数を自動的に使用します。
- `gh` CLI を使う場合は `additional-apps` で事前にインストール確認をします。

---

## シナリオ 4: 追加ツールの検証 (additional-apps)

デフォルト (Git・curl) 以外のツールをバージョン要件付きで検証する設定です。

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
        with:
          actions-type: commit
          additional-apps: |
            gh|GitHub CLI|field:3|2.0
            node|Node.js|regex:v([0-9.]+)|20.0
            jq|jq|regex:([0-9.]+)|1.6
```

<!-- markdownlint-disable line-length MD060 -->

| 列     | 意味                                                                    |
| ------ | ----------------------------------------------------------------------- |
| 1 列目 | コマンド名 (PATH 上の実行ファイル名)                                    |
| 2 列目 | 表示名 (ログやエラーメッセージで使用)                                   |
| 3 列目 | バージョン抽出方法 (`field:N` / `regex:PATTERN` / 空欄=自動抽出)        |
| 4 列目 | 最低バージョン (空欄にするとバージョンチェックをスキップして警告を出す) |

<!-- markdownlint-enable line-length MD060 -->

補足:

- `additional-apps` に指定するツールは、runner にあらかじめインストール済みであることが前提です。
  カスタムランナーを使う場合は事前に確認してください。
- このアクションはインストーラーではなく、失敗を早期検出するゲートです。ツールのセットアップは別ステップで行ってください。

---

## シナリオ 5: パーミッション検証をスキップ (`any`)

特殊な権限構成のランナーや、パーミッション検証が不要な場合に使用します。
`GITHUB_TOKEN` の存在確認のみ行い、権限プローブは実行しません。

```yaml
jobs:
  special:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Validate environment
        uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
        with:
          actions-type: any
```

補足:

- `any` は例外的な用途向けです。通常のワークフローでは `read` / `commit` / `pr` のいずれかを使用してください。
- 多用すると CI の設計意図が曖昧になるため、使用箇所は最小限に留めてください。

---

## 📚 関連ドキュメント

- [クイックスタート](./11-quickstart.ja.md): 最小構成での利用手順
- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
