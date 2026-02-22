---
title: トラブルシューティング
description: validate-environment でよく発生するエラーと解決方法
slug: troubleshooting
sidebar_position: 90
tags:
  - validate-environment
  - troubleshooting
  - errors
---

## 🔍 トラブルシューティング

このページでは、`validate-environment` の実行時に発生しやすいエラーと解決方法を説明します。
エラーは GitHub Actions のログに `::error::` 形式で出力されます。

---

## 🖥️ ランナー関連のエラー

### This action requires Linux

**原因**: `runs-on` に Linux 以外のランナーを指定している。

**解決方法**: `ubuntu-latest` など Linux 系ランナーに変更してください。

```yaml
# NG
runs-on: windows-latest

# OK
runs-on: ubuntu-latest
```

### Invalid architecture input

**原因**: `architecture` に `amd64` / `arm64` 以外の値を指定している。

**解決方法**: `amd64` または `arm64` のみ指定できます。

```yaml
with:
  architecture: amd64 # amd64 または arm64
```

### Architecture mismatch

**原因**: `architecture` に指定した値と、実際のランナーのアーキテクチャが一致しない。

**解決方法**: ランナーのアーキテクチャに合わせて `architecture` を修正するか、対応するランナーを使用してください。

```yaml
# amd64 ランナーを使う場合
runs-on: ubuntu-latest
with:
  architecture: amd64
```

### This action requires a GitHub-hosted runner

**原因**: `require-github-hosted: "true"` に設定しているが、セルフホストランナーで実行している。

**解決方法**: GitHub ホステッドランナーに変更するか、`require-github-hosted` を `"false"` にしてください。

```yaml
# セルフホストランナーを許可する場合
with:
  require-github-hosted: "false"
```

### Required environment variables are not set

**原因**: GitHub Actions 環境外 (ローカルなど) で実行している。

**解決方法**: `validate-environment` は GitHub Actions ワークフロー内でのみ動作します。ローカル実行はサポートしていません。

## 🔑 パーミッション関連のエラー

### GITHUB_TOKEN is not configured

**原因**: `GITHUB_TOKEN` がワークフローで利用できない状態になっている。

**解決方法**: `permissions` セクションを明示的に設定してください。GitHub Actions では `GITHUB_TOKEN` は自動的に提供されますが、権限が不足していると検証に失敗します。

```yaml
permissions:
  contents: read
```

### Permission denied (403)

**原因**: `actions-type` に指定した操作種別に対して、`GITHUB_TOKEN` の権限が不足している。

**解決方法**: `actions-type` に応じた `permissions` を設定してください。

<!-- markdownlint-disable line-length MD060 -->

| `actions-type` | 必要な permissions                         |
| -------------- | ------------------------------------------ |
| `read`         | `contents: read`                           |
| `commit`       | `contents: write`                          |
| `pr`           | `contents: write` + `pull-requests: write` |

<!-- markdownlint-enable line-length MD060 -->

```yaml
# pr の場合
permissions:
  contents: write
  pull-requests: write
```

### Authentication failed (401)

**原因**: `GITHUB_TOKEN` が無効または期限切れになっている。

**解決方法**: ワークフローを再実行してください。トークンは通常 GitHub Actions が自動で管理するため、手動での操作は不要です。問題が続く場合はリポジトリの設定を確認してください。

### Network error: unable to reach GitHub API

**原因**: GitHub API へのネットワーク接続に失敗した。

**解決方法**: ランナーのネットワーク設定を確認してください。セルフホストランナーの場合は、`api.github.com` への疎通を確認してください。

### Invalid actions-type

**原因**: `actions-type` に有効な値以外を指定している。

**解決方法**: `read` / `commit` / `pr` / `any` のいずれかを指定してください。

```yaml
with:
  actions-type: read # read, commit, pr, any のいずれか
```

## 📦 アプリケーション関連のエラー

### `<アプリ名>` is not installed

**原因**: `additional-apps` に指定したアプリがランナーにインストールされていない。

**解決方法**: `validate-environment` より前のステップでツールをインストールしてください。
インストール手順は各ツールの公式ドキュメントを参照してください。

### `<アプリ名>` version X.Y is below minimum required Z.W

**原因**: インストールされているバージョンが `min_version` の要件を下回っている。

**解決方法**: ツールを最新バージョンにアップグレードするか、`min_version` を現在のバージョンに合わせて調整してください。

### No semver pattern found / Pattern did not match

**原因**: `additional-apps` の `version_extractor` がコマンドの出力と一致しない。

**解決方法**: `--version` の出力を確認して、抽出方式を修正してください。

バージョン確認:

```bash
# ランナー上でコマンドの出力形式を確認する
gh --version
# → gh version 2.74.0 (2025-02-13)
```

バージョン抽出:

```yaml
# 確認した出力に合わせて抽出方式を設定する
additional-apps: |
  gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

バージョン抽出方式の詳細は [リファレンス](./13-reference.ja.md) を参照してください。

### Invalid app definition format

**原因**: `additional-apps` の書式が正しくない。フィールド数が 2 または 4 以外になっている。

**解決方法**: `cmd|app_name|version_extractor|min_version` の 4 フィールド形式で記述してください。

```yaml
# NG: フィールド数が合っていない
additional-apps: |
  gh|GitHub CLI|auto

# OK: 4 フィールド形式
additional-apps: |
  gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

### Too many apps specified (max: 30)

**原因**: `additional-apps` に 30 件を超えるアプリを指定している。

**解決方法**: 検証するアプリを 30 件以内に絞ってください。

### gh is not authenticated

**原因**: `gh` CLI が GitHub に認証されていない。

**解決方法**: `gh` を使う場合は、`additional-apps` に `gh` を追加し、`permissions` に `contents: read` 以上を設定してください。
GitHub Actions では `GITHUB_TOKEN` を使って自動認証されます。

```yaml
permissions:
  contents: read

steps:
  - uses: aglabo/ci-platform/.github/actions/validate-environment@v0.1.0
    with:
      additional-apps: |
        gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

---

## 📚 関連ドキュメント

- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
