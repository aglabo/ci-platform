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

`validate-environment` の実行時に発生しやすいエラーと解決方法を説明します。
エラーは GitHub Actions のログに `::error::` 形式で出力されます。

> `validate-environment` は実行基盤の整合性を検証するゲートです。
> アプリケーションロジックやビルドの正当性は検証対象外です。

---

## ✅ 最初に確認すべき 3 点

1. **`permissions` が明示されているか** — `contents: read` 以上が必要
2. **Linux ランナーを使用しているか** — `runs-on: ubuntu-latest` など
3. **`additional-apps` の書式が正しいか** — 2 フィールド (`cmd|name`) または 4 フィールド (`cmd|name|extractor|version`) 形式

---

## 🖥️ ランナー関連のエラー

### This action requires Linux

```text
::error::This action requires Linux
```

**原因**: `runs-on` に Linux 以外のランナーを指定している。

**解決方法**: `ubuntu-latest` など Linux 系ランナーに変更してください。

```yaml
# NG
runs-on: windows-latest

# OK
runs-on: ubuntu-latest
```

### Invalid architecture input

```text
::error::Invalid architecture input: x86
```

**原因**: `architecture` に `amd64` / `arm64` 以外の値を指定している。

**解決方法**: `amd64` または `arm64` のみ指定できます。
GitHub ホステッドの Ubuntu ランナー (`ubuntu-latest`) は通常 `amd64` です。

```yaml
with:
  architecture: amd64 # amd64 または arm64
```

### Architecture mismatch

```text
::error::Architecture mismatch: expected amd64, got arm64
```

**原因**: `architecture` に指定した値と実際のランナーのアーキテクチャが一致しない。

**解決方法**: ランナーのアーキテクチャに合わせて `architecture` を修正するか、対応するランナーを使用してください。

```yaml
# amd64 ランナーを使う場合
runs-on: ubuntu-latest
with:
  architecture: amd64
```

### This action requires a GitHub-hosted runner

```text
::error::This action requires a GitHub-hosted runner
```

**原因**: `require-github-hosted: "true"` に設定しているが、セルフホストランナーで実行している。

**解決方法**: GitHub ホステッドランナーに変更するか、`require-github-hosted` を `"false"` にしてください。

```yaml
with:
  require-github-hosted: "false"
```

### Required environment variables are not set

```text
::error::Required environment variables are not set
```

**原因**: GitHub Actions 以外の環境 (ローカル実行など) で実行している。

**解決方法**: `validate-environment` は GitHub Actions 環境変数に依存します。
ローカルで実行する場合は、必要な環境変数を明示的に設定してください。

---

## 🔑 パーミッション関連のエラー

### GITHUB_TOKEN is not configured

```text
::error::GITHUB_TOKEN is not configured
```

**原因**: `GITHUB_TOKEN` がワークフローで利用できない状態になっている。

**解決方法**: `permissions` セクションを明示的に設定してください。
fork PR では `write` 系パーミッションが自動的に制限されることがあります。

```yaml
permissions:
  contents: read
```

### Permission denied (403)

```text
::error::Permission denied (403)
```

**原因**: `actions-type` に指定した操作種別に対して `GITHUB_TOKEN` の権限が不足している。

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

```text
::error::Authentication failed (401)
```

**原因**: `GITHUB_TOKEN` が無効または期限切れになっている。

**解決方法**: ワークフローを再実行してください。問題が続く場合はリポジトリの設定を確認してください。

### Network error: unable to reach GitHub API

```text
::error::Network error: unable to reach GitHub API
```

**原因**: GitHub API へのネットワーク接続に失敗した。

**解決方法**: セルフホストランナーの場合は `api.github.com` への疎通を確認してください。

### Invalid actions-type

```text
::error::Invalid actions-type: unknown
```

**原因**: `actions-type` に有効な値以外を指定している。

**解決方法**: `read` / `commit` / `pr` / `any` のいずれかを指定してください。

> `any` は開発用途専用の緩和モードです。本番 CI では `read` / `commit` / `pr` のいずれかを明示してください。

---

## 📦 アプリケーション関連のエラー

### `<アプリ名>` is not installed

```text
::error::jq is not installed
```

**原因**: `additional-apps` に指定したアプリがランナーにインストールされていない。

**解決方法**: `validate-environment` より前のステップでツールをインストールしてください。

### `<アプリ名>` version X.Y is below minimum required Z.W

```text
::error::jq version 1.5 is below minimum required 1.6
```

**原因**: インストールされているバージョンが `min_version` の要件を下回っている。

**解決方法**: ツールをアップグレードするか、`min_version` を現在のバージョンに合わせて調整してください。

### No semver pattern found / Pattern did not match

```text
::error::No semver pattern found in output of jq
```

**原因**: `version_extractor` がコマンドの出力と一致しない。

**解決方法**: `--version` の出力を確認して抽出方式を修正してください。

```bash
# ランナー上でコマンドの出力形式を確認する
gh --version
# → gh version 2.74.0 (2025-02-13)
```

```yaml
additional-apps: |
  gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

バージョン抽出方式の詳細は[リファレンス](./13-reference.ja.md)を参照してください。

### Invalid app definition format

```text
::error::Invalid app definition format: gh|GitHub CLI|auto
```

**原因**: `additional-apps` のフィールド数が 2 または 4 以外になっている。

**解決方法**: 2 フィールド (`cmd|app_name`) または 4 フィールド (`cmd|app_name|version_extractor|min_version`) で記述してください。

```yaml
# NG: 3 フィールドはエラー
additional-apps: |
  gh|GitHub CLI|auto

# OK: 2 フィールド (バージョンチェックなし)
additional-apps: |
  gh|GitHub CLI

# OK: 4 フィールド (バージョンチェックあり)
additional-apps: |
  gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

### Too many apps specified (max: 30)

```text
::error::Too many apps specified (max: 30)
```

**原因**: `additional-apps` に 30 件を超えるアプリを指定している。

**解決方法**: 検証するアプリを 30 件以内に絞ってください。

### gh is not authenticated

```text
::error::gh is not authenticated
```

**原因**: `gh` CLI が GitHub に認証されていない。

**解決方法**: `permissions` に `contents: read` 以上を設定してください。
GitHub Actions では `GITHUB_TOKEN` を使って自動認証されます。

```yaml
permissions:
  contents: read

steps:
  - uses: aglabo/ci-platform/.github/actions/validate-environment@21e02575bb3c3ec61a149801d696b53669f85208 # v0.1.0
    with:
      additional-apps: |
        gh|GitHub CLI|regex:version ([0-9.]+)|2.0
```

---

## 📚 関連ドキュメント

- [リファレンス](./13-reference.ja.md): 全入力パラメータ・出力の詳細
- [利用シナリオ](./12-basic-scenarios.ja.md): 典型的な利用例
